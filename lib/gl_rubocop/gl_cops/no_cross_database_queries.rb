# frozen_string_literal: true

require 'set'
require_relative '../helpers/active_record_model_registry'

module GLRubocop
  module GLCops
    # Prevents cross-database joins, references, raw SQL joins, and subqueries
    # between primary ApplicationRecord models and versions/datawarehouse models.
    #
    # Good:
    #   ids = SalesforceSync.successful.pluck(:salesforce_syncable_id)
    #   Campaign.where(id: ids)
    #   Campaign.preload(:salesforce_syncs)
    #
    # Bad:
    #   Campaign.joins(:salesforce_syncs)
    #   Campaign.left_joins(:salesforce_syncs)
    #   Campaign.includes(:salesforce_syncs).references(:salesforce_syncs)
    #   Campaign.where(SalesforceSync.arel_table[:success].eq(true))
    class NoCrossDatabaseQueries < RuboCop::Cop::Base # rubocop:disable Metrics/ClassLength
      MSG_ASSOC = 'Do not join cross-database association `%<target>s` (%<target_db>s) ' \
                  'from a %<source_db>s query. Fetch IDs separately and query in two steps.'
      MSG_SQL = 'Do not reference `%<target>s` (%<target_db>s) in a %<source_db>s SQL ' \
                'query. Fetch IDs separately and query in two steps.'
      MSG_AREL = 'Do not mix `%<target>s` (%<target_db>s) into a %<source_db>s query. ' \
                 'Fetch IDs separately with pluck before querying.'

      JOIN_METHODS = %i[joins left_joins left_outer_joins eager_load references].freeze
      SQL_JOIN_METHODS = %i[joins left_joins left_outer_joins from].freeze
      SQL_QUERY_METHODS = %i[
        where not rewhere select reselect order reorder group having from find_by_sql
      ].freeze
      INCLUDES_CONFLICT_METHODS = %i[
        where not rewhere select reselect order reorder group having
      ].freeze
      QUERY_METHODS = %i[
        where not rewhere or and merge joins left_joins left_outer_joins
        from order reorder group having select reselect find_by_sql
      ].freeze
      SUBQUERY_VALUE_METHODS = %i[where not rewhere].freeze
      RELATION_COMBINATOR_METHODS = %i[merge or and].freeze
      RELATION_METHODS = %i[
        all where not rewhere select reselect from joins left_joins left_outer_joins
        eager_load includes preload references order reorder group having limit offset
        distinct unscoped default_scoped merge or and none readonly lock scoping
        only except reverse_order extending invert_where excluding without
        associated missing
      ].freeze
      AREL_METHODS = %i[arel_table arel].freeze
      MATERIALIZING_METHODS = %i[
        pluck ids pick to_a map collect first last take find find_by find_by!
        find_or_create_by find_or_create_by! find_or_initialize_by find_or_initialize_by!
        create create! new build sole find_sole_by
        count size length exists? empty? any? none? maximum minimum sum average
        table_name name polymorphic_name base_class model_name primary_key column_names
        connection defined_enums sanitize_sql sanitize_sql_array
        sanitize_sql_for_conditions sanitize_sql_for_assignment sanitize_sql_like
      ].freeze
      ASSOC_CONTAINER_TYPES = %i[array hash pair].freeze
      BLOCK_ARG_TYPES = %i[arg optarg restarg kwarg kwoptarg kwrestarg blockarg shadowarg].freeze
      SQL_TABLE_PATTERN =
        /\b(?:JOIN|FROM)\s+(?:"?[a-z_][a-z0-9_]*"?\.)?"?([a-z_][a-z0-9_]*)"?/i
      FROM_LEADING_TABLE_PATTERN =
        /\A\s*(?:"?[a-z_][a-z0-9_]*"?\.)?"?([a-z_][a-z0-9_]*)"?/i
      EXTRACT_PATTERN = /\bEXTRACT\s*\([^)]*\)/i
      QUOTED_LITERAL_PATTERN = /'(?:''|[^'])*'/
      INTERPOLATED_PREFIX = '__gl_interp_'
      SQL_KEYWORDS = %w[
        lateral only values unnest generate_series select null
      ].freeze
      UNSET = Object.new.freeze

      def on_send(node)
        check_join_or_reference(node) if JOIN_METHODS.include?(node.method_name)
        check_query_arguments(node) if QUERY_METHODS.include?(node.method_name)
        check_includes_with_conditions(node)
      end
      alias_method :on_csend, :on_send

      def on_lvasgn(node)
        var_name, value = *node
        record_block_assignment(var_name)
        db = relation_db_group(value, allow_scope_call: true)
        db ? var_db_groups[var_name] = db : var_db_groups.delete(var_name)
      end

      def on_block(node)
        schedule_block_scope(node, block_param_names(node.arguments))
      end

      def on_numblock(node)
        params = (1..9).map { |i| :"_#{i}" } << :it
        schedule_block_scope(node, params)
      end

      def on_itblock(node)
        schedule_block_scope(node, [:it])
      end

      def after_send(node)
        params = pending_block_scopes.delete(node)
        push_block_scope(params) if params
      end
      alias_method :after_csend, :after_send

      def after_block(_node)
        scope = block_scope_stack.pop
        return unless scope

        scope[:saved].each do |var, prev|
          prev.equal?(UNSET) ? var_db_groups.delete(var) : var_db_groups[var] = prev
        end
        scope[:new_lvars].each { |var| defined_lvars.delete(var) }
      end
      alias_method :after_numblock, :after_block
      alias_method :after_itblock, :after_block

      def on_def(_node)
        var_db_groups.clear
        defined_lvars.clear
        block_scope_stack.clear
        pending_block_scopes.clear
      end
      alias_method :on_defs, :on_def

      private

      def schedule_block_scope(node, params)
        send_node = node.send_node
        if send_node&.send_type? || send_node&.csend_type?
          pending_block_scopes[send_node] = params
        else
          push_block_scope(params)
        end
      end

      def push_block_scope(params)
        saved = {}
        param_map = {}
        params.each do |param|
          saved[param] = var_db_groups.key?(param) ? var_db_groups[param] : UNSET
          var_db_groups.delete(param)
          param_map[param] = true
        end
        block_scope_stack << { saved:, params: param_map, new_lvars: [] }
      end

      def record_block_assignment(var_name)
        scope = block_scope_stack.last
        unless !scope || scope[:params].key?(var_name) || defined_lvars.key?(var_name)
          scope[:saved][var_name] = UNSET unless scope[:saved].key?(var_name)
          scope[:new_lvars] << var_name
        end
        defined_lvars[var_name] = true
      end

      def block_param_names(args_node)
        return [] unless args_node

        args_node.children.each_with_object([]) do |arg, names|
          names << arg.children.first if BLOCK_ARG_TYPES.include?(arg.type)
        end
      end

      def source_db_for_call(node)
        node.receiver ? chain_root_db_group(node.receiver) : enclosing_model_db(node)
      end

      def check_join_or_reference(node)
        source_db = source_db_for_call(node)
        node.arguments.each do |arg|
          check_assoc_arg(arg, source_db) if source_db || node.receiver
          if SQL_JOIN_METHODS.include?(node.method_name)
            check_sql_arg(arg, source_db, from_clause: node.method_name == :from)
          end
        end
      end

      def check_assoc_arg(node, source_db)
        effective_source = source_db || :primary
        each_assoc_symbol(node) do |sym_node, name|
          target_db = non_primary_associations[name]
          next unless target_db && effective_source != target_db

          add_offense(
            sym_node,
            message: format(MSG_ASSOC, target: name, target_db:, source_db: effective_source)
          )
        end
      end

      def check_includes_with_conditions(node)
        if INCLUDES_CONFLICT_METHODS.include?(node.method_name)
          check_conditions_against_prior_includes(node)
        elsif node.method_name == :includes
          check_includes_against_prior_conditions(node)
        end
      end

      def check_conditions_against_prior_includes(node)
        included = chained_included_assocs(node.receiver)
        return if included.empty?

        source_db = chain_source_db(node)
        cross_db = included.reject { |_, db| db == source_db }
        return if cross_db.empty?

        node.arguments.each { |arg| check_condition_against_included(arg, cross_db, source_db) }
      end

      def check_includes_against_prior_conditions(node)
        source_db = chain_source_db(node)
        cross_db = extract_cross_db_assocs(node.arguments, source_db)
        return if cross_db.empty?

        prior_condition_nodes(node.receiver).each do |cond_node|
          cond_node.arguments.each do |arg|
            check_condition_against_included(arg, cross_db, source_db)
          end
        end
      end

      def chain_source_db(node)
        chain_root_db_group(node.receiver) || enclosing_model_db(node) || :primary
      end

      def extract_cross_db_assocs(args, source_db)
        args.each_with_object({}) do |arg, acc|
          each_assoc_symbol(arg) do |_, name|
            target_db = non_primary_associations[name]
            acc[name] = target_db if target_db && target_db != source_db
          end
        end
      end

      def chained_included_assocs(node)
        assocs = {}
        current = node
        while current&.send_type? || current&.csend_type?
          if current.method_name == :includes
            current.arguments.each do |arg|
              each_assoc_symbol(arg) do |_, name|
                target_db = non_primary_associations[name]
                assocs[name] = target_db if target_db
              end
            end
          end
          current = current.receiver
        end
        assocs
      end

      def prior_condition_nodes(node)
        nodes = []
        current = node
        while current&.send_type? || current&.csend_type?
          nodes << current if INCLUDES_CONFLICT_METHODS.include?(current.method_name)
          current = current.receiver
        end
        nodes
      end

      def check_condition_against_included(arg, cross_db_assocs, source_db)
        if arg.hash_type?
          check_hash_condition_against_included(arg, cross_db_assocs, source_db)
        elsif arg.str_type? || arg.dstr_type?
          check_sql_condition_against_included(arg, cross_db_assocs, source_db)
        elsif arg.array_type? && arg.children.first
          check_condition_against_included(arg.children.first, cross_db_assocs, source_db)
        end
      end

      def check_hash_condition_against_included(hash_node, cross_db_assocs, source_db)
        hash_node.pairs.each do |pair|
          next unless pair.key.sym_type? || pair.key.str_type?

          match = matching_included_assoc(pair.key.value.to_s, cross_db_assocs)
          next unless match

          assoc_name, target_db = match
          add_offense(
            pair.key,
            message: format(MSG_ASSOC, target: assoc_name, target_db:, source_db:)
          )
        end
      end

      def check_sql_condition_against_included(sql_node, cross_db_assocs, source_db)
        text = strip_sql_literals(sql_node.str_type? ? sql_node.value : dstr_text(sql_node))
        cross_db_assocs.each do |assoc_name, target_db|
          tables = [assoc_name, pluralize_table_segment(assoc_name)].uniq
          next unless tables.any? { |tbl| text.match?(/\b#{Regexp.escape(tbl)}\./i) }

          add_offense(
            sql_node,
            message: format(MSG_ASSOC, target: assoc_name, target_db:, source_db:)
          )
          break
        end
      end

      def matching_included_assoc(key_name, cross_db_assocs)
        cross_db_assocs.find do |assoc_name, _|
          key_name == assoc_name || key_name == pluralize_table_segment(assoc_name)
        end
      end

      def each_assoc_symbol(node, &block)
        return unless node.is_a?(Parser::AST::Node)

        if node.sym_type? || node.str_type?
          yield node, node.value.to_s
        elsif ASSOC_CONTAINER_TYPES.include?(node.type)
          node.children.each { |child| each_assoc_symbol(child, &block) }
        end
      end

      def check_sql_arg(node, source_db, from_clause: false)
        sql_node = unwrap_sql_node(node)
        return unless sql_node

        effective_source = source_db || :primary
        tables, interp_sends = extract_sql_tables_and_interps(sql_node, from_clause:)
        check_interpolated_models(sql_node, interp_sends, effective_source) if sql_node.dstr_type?
        tables.each do |table|
          next if table.start_with?(INTERPOLATED_PREFIX)

          check_sql_table(sql_node, table, effective_source)
        end
      end

      def unwrap_sql_node(node)
        target = node.array_type? ? node.children.first : node
        target if target&.str_type? || target&.dstr_type?
      end

      def check_interpolated_models(node, interp_sends, source_db)
        interp_sends.each do |send_node|
          target_db = const_db_group(send_node.receiver)
          next unless target_db && target_db != source_db

          target = full_const_name(send_node.receiver)
          report_sql(node, target, target_db, source_db)
        end
      end

      def check_sql_table(node, table, source_db)
        return if SQL_KEYWORDS.include?(table.downcase)

        dbs = table_ownership[table]
        return unless dbs&.none?(source_db)

        target_db = dbs.include?(:primary) ? :primary : dbs.first
        report_sql(node, table, target_db, source_db)
      end

      def extract_sql_tables_and_interps(node, from_clause:)
        if node.str_type?
          [scan_tables(node.value, from_clause:), []]
        else
          text, placeholders = dstr_sql_with_placeholders(node)
          tables = scan_tables(text, from_clause:)
          interps = tables.filter_map { |tbl| placeholders[tbl] }
          [tables, interps]
        end
      end

      def scan_tables(raw_text, from_clause:)
        text = strip_sql_literals(raw_text).gsub(EXTRACT_PATTERN, '')
        tables = text.scan(SQL_TABLE_PATTERN).flatten
        tables.concat(text.scan(FROM_LEADING_TABLE_PATTERN).flatten) if from_clause
        tables.uniq
      end

      def strip_sql_literals(text)
        text.gsub(QUOTED_LITERAL_PATTERN, "''")
      end

      def dstr_text(node)
        node.children.map { |child| child.str_type? ? child.value : '__interp__' }.join
      end

      def dstr_sql_with_placeholders(node)
        placeholders = {}
        parts = node.children.each_with_index.map do |child, idx|
          if child.str_type?
            child.value
          else
            send_node = interpolated_table_name_send(child)
            token = "#{INTERPOLATED_PREFIX}#{idx}__"
            placeholders[token] = send_node if send_node
            token
          end
        end
        [parts.join, placeholders]
      end

      def interpolated_table_name_send(node)
        return nil unless node.begin_type?

        inner = node.children.first
        return nil unless inner&.send_type? && inner.method_name == :table_name
        return nil unless inner.receiver&.const_type?

        inner
      end

      def report_sql(node, target, target_db, source_db)
        add_offense(node, message: format(MSG_SQL, target:, target_db:, source_db:))
      end

      def check_query_arguments(node)
        source_db = source_db_for_call(node)
        from_clause = node.method_name == :from
        node.arguments.each do |arg|
          if source_db
            check_sql_arg(arg, source_db, from_clause:) if sql_method?(node)
            check_query_arg_relations(node, arg, source_db)
          else
            check_sql_arg(arg, nil, from_clause:) if sql_method?(node) && node.receiver.nil?
            check_mixed_arel_tables(arg)
          end
        end
      end

      def check_query_arg_relations(node, arg, source_db)
        if SUBQUERY_VALUE_METHODS.include?(node.method_name) && arg.hash_type?
          arg.pairs.each do |pair|
            check_mixed_arel_or_subquery(pair.value, source_db, allow_scope_call: true)
          end
        elsif RELATION_COMBINATOR_METHODS.include?(node.method_name)
          check_mixed_arel_or_subquery(arg, source_db, allow_scope_call: true)
        else
          check_mixed_arel_or_subquery(arg, source_db)
        end
      end

      def sql_method?(node)
        SQL_QUERY_METHODS.include?(node.method_name)
      end

      def check_mixed_arel_tables(node)
        arel_nodes = collect_arel_table_nodes(node)
        return if arel_nodes.empty? || arel_nodes.one?

        non_primary = arel_nodes.find { |n| non_primary_arel_db(n) }
        return unless non_primary

        target_db = non_primary_arel_db(non_primary)
        other = arel_nodes.find { |n| arel_node_db(n) != target_db }
        return unless other

        target = full_const_name(non_primary.receiver)
        message = format(MSG_AREL, target:, target_db:, source_db: :primary)
        add_offense(non_primary, message:)
      end

      def collect_arel_table_nodes(node, acc = [])
        return acc unless node.is_a?(Parser::AST::Node)

        acc << node if node.send_type? && node.method_name == :arel_table
        node.children.each { |child| collect_arel_table_nodes(child, acc) }
        acc
      end

      def non_primary_arel_db(node)
        db = arel_node_db(node)
        db if db && db != :primary
      end

      def arel_node_db(node)
        return :primary unless node.receiver&.const_type?

        const_db_group(node.receiver) || :primary
      end

      def check_mixed_arel_or_subquery(node, source_db, allow_scope_call: false)
        return unless node.is_a?(Parser::AST::Node)
        return if materializing_send?(node)

        if (match = cross_db_ref(node, source_db, allow_scope_call:))
          target, target_db = match
          add_offense(node, message: format(MSG_AREL, target:, target_db:, source_db:))
          return
        end

        node.children.each { |child| check_mixed_arel_or_subquery(child, source_db) }
      end

      def materializing_send?(node)
        (node.send_type? || node.csend_type?) && MATERIALIZING_METHODS.include?(node.method_name)
      end

      def cross_db_ref(node, source_db, allow_scope_call: false)
        return lvar_cross_db_ref(node, source_db) if node.lvar_type?
        if node.send_type? || node.csend_type?
          return send_cross_db_ref(node, source_db, allow_scope_call:)
        end

        nil
      end

      def lvar_cross_db_ref(node, source_db)
        name = node.children.first
        db = var_db_groups[name]
        [name, db] if db && db != source_db
      end

      def send_cross_db_ref(node, source_db, allow_scope_call: false)
        return nil if node.receiver&.lvar_type?

        db = relation_send_db_group(node, allow_scope_call:)
        return nil unless db && db != source_db

        target = root_const_name(node) || node.method_name
        [target, db]
      end

      def relation_or_arel_send?(node)
        RELATION_METHODS.include?(node.method_name) ||
          AREL_METHODS.include?(node.method_name) ||
          non_primary_associations.key?(node.method_name.to_s)
      end

      def relation_db_group(node, allow_scope_call: false)
        return nil unless node.is_a?(Parser::AST::Node)

        if node.lvar_type?
          var_db_groups[node.children.first]
        elsif node.send_type? || node.csend_type?
          relation_send_db_group(node, allow_scope_call:)
        end
      end

      def relation_send_db_group(node, allow_scope_call: false)
        return nil if MATERIALIZING_METHODS.include?(node.method_name)

        if relation_or_arel_send?(node)
          return non_primary_associations[node.method_name.to_s] ||
                 receiver_or_enclosing_db(node)
        end

        return nil unless allow_scope_call

        scoped_relation_send_db_group(node)
      end

      def scoped_relation_send_db_group(node)
        return nil if node.method_name == :[] || node.method_name.to_s.end_with?('?')
        return nil unless root_const_name(node)

        chain_root_db_group(node.receiver)
      end

      def receiver_or_enclosing_db(node)
        node.receiver ? chain_root_db_group(node.receiver) : enclosing_model_db(node)
      end

      def chain_root_db_group(node)
        return nil unless node.is_a?(Parser::AST::Node)

        case node.type
        when :lvar then var_db_groups[node.children.first]
        when :const then const_db_group(node)
        when :self then enclosing_model_db(node)
        when :send, :csend then send_chain_root_db_group(node)
        end
      end

      def send_chain_root_db_group(node)
        return nil if MATERIALIZING_METHODS.include?(node.method_name)

        non_primary_associations[node.method_name.to_s] || receiver_or_enclosing_db(node)
      end

      def root_const_name(node)
        current = node
        current = current.receiver while current.respond_to?(:receiver) && current.receiver
        full_const_name(current) if current&.const_type?
      end

      def enclosing_model_db(node)
        class_node = node.each_ancestor(:class).first
        return nil unless class_node

        const_db_group(class_node.children[0]) || const_db_group(class_node.children[1])
      end

      def const_db_group(const_node)
        return nil unless const_node&.const_type?

        name = full_const_name(const_node)
        return model_db_groups[name] if anchored_at_cbase?(const_node)

        enclosing_namespaces(const_node).each do |ns|
          candidate = "#{ns}::#{name}"
          return model_db_groups[candidate] if model_db_groups.key?(candidate)
        end
        model_db_groups[name]
      end

      def anchored_at_cbase?(node)
        current = node
        current = current.children[0] while current&.const_type?
        current&.cbase_type?
      end

      def enclosing_namespaces(node)
        parts = node.each_ancestor(:module, :class).map { |anc| full_const_name(anc.children[0]) }
        parts.reverse.each_with_object([]) do |seg, acc|
          acc.unshift(acc.empty? ? seg : "#{acc.first}::#{seg}")
        end
      end

      def full_const_name(node)
        return nil unless node&.const_type?

        parts = []
        current = node
        while current&.const_type?
          parts.unshift(current.children[1].to_s)
          current = current.children[0]
        end
        parts.join('::')
      end

      def var_db_groups
        @var_db_groups ||= {}
      end

      def defined_lvars
        @defined_lvars ||= {}
      end

      def block_scope_stack
        @block_scope_stack ||= []
      end

      def pending_block_scopes
        @pending_block_scopes ||= {}.compare_by_identity
      end

      def model_db_groups
        GLRubocop::Helpers::ActiveRecordModelRegistry.database_groups_for(
          project_root: RuboCop::ConfigFinder.project_root,
          globs: model_globs,
          non_primary_base_classes: cop_config.fetch('NonPrimaryBaseClasses', {}),
          non_primary_models: cop_config.fetch('NonPrimaryModels', {})
        )
      end

      def model_globs
        cop_config.fetch('ModelGlobs', GLRubocop::Helpers::ActiveRecordModelRegistry::ALL_MODEL_GLOBS)
      end

      def non_primary_associations
        @non_primary_associations ||= invert_db_map(
          cop_config.fetch('NonPrimaryAssociations', {})
        )
      end

      def non_primary_tables
        @non_primary_tables ||= invert_db_set_map(
          cop_config.fetch('NonPrimaryTables', {})
        )
      end

      def table_ownership
        @table_ownership ||= begin
          ownership = configured_table_ownership
          merge_inferred_model_tables!(ownership)
          ownership
        end
      end

      def configured_table_ownership
        non_primary_tables.transform_values do |dbs|
          dbs.include?(:datawarehouse) ? Set[:primary] | dbs : dbs.dup
        end
      end

      def merge_inferred_model_tables!(ownership)
        model_db_groups.each do |model_name, db|
          table = model_to_table_name(model_name)
          next if ownership.key?(table) && db == :primary

          (ownership[table] ||= Set.new) << db
        end
      end

      def model_to_table_name(model_name)
        snake = model_name.split('::').last
                          .gsub(/([A-Z\d]+)([A-Z][a-z])/, '\1_\2')
                          .gsub(/([a-z\d])([A-Z])/, '\1_\2')
                          .downcase
        pluralize_table_segment(snake)
      end

      def pluralize_table_segment(word)
        return "#{word[0..-4]}ses" if word.end_with?('sis')
        return word if word.end_with?('s') && !word.end_with?('ss', 'us')
        return "#{word[0..-2]}ies" if word.match?(/[^aeiou]y\z/)
        return "#{word}es" if word.end_with?('s', 'x', 'z', 'ch', 'sh')

        "#{word}s"
      end

      def invert_db_map(mapping)
        mapping.each_with_object({}) do |(db, items), result|
          Array(items).each { |item| result[item.to_s] = db.to_sym }
        end
      end

      def invert_db_set_map(mapping)
        mapping.each_with_object({}) do |(db, items), result|
          Array(items).each do |item|
            result[item.to_s] ||= Set.new
            result[item.to_s] << db.to_sym
          end
        end
      end
    end
  end
end
