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
      SQL_QUERY_METHODS = %i[where not from].freeze
      QUERY_METHODS = %i[
        where not or and merge joins left_joins left_outer_joins
        from order group having select reselect
      ].freeze
      MATERIALIZING_METHODS = %i[
        pluck ids pick to_a map collect first last take find find_by find_by!
        find_or_create_by find_or_create_by! find_or_initialize_by create create!
        count size length exists? empty? any? none? maximum minimum sum average
        table_name name polymorphic_name base_class model_name primary_key column_names
      ].freeze
      ASSOC_CONTAINER_TYPES = %i[array hash pair].freeze
      BLOCK_ARG_TYPES = %i[arg optarg restarg kwarg kwoptarg kwrestarg blockarg shadowarg].freeze
      SQL_TABLE_PATTERN = /\b(?:JOIN|FROM)\s+"?([a-z_][a-z0-9_]*)"?/i
      FROM_LEADING_TABLE_PATTERN = /\A\s*"?([a-z_][a-z0-9_]*)"?/i
      EXTRACT_PATTERN = /\bEXTRACT\s*\([^)]*\)/i
      INTERPOLATED_PLACEHOLDER = '__interpolated__'
      SQL_KEYWORDS = %W[
        lateral only values unnest generate_series select null #{INTERPOLATED_PLACEHOLDER}
      ].freeze

      DEFAULT_BASE_CLASSES = {
        'versions' => %w[VersionRecord ShadowRecord],
        'datawarehouse' => %w[Datawarehouse::BaseRecord]
      }.freeze
      DEFAULT_MODELS = {
        'versions' => %w[SalesforceSync AdminSalesforceSync]
      }.freeze
      DEFAULT_ASSOCIATIONS = {
        'versions' => %w[salesforce_syncs versions tracked_workflows workflow_events]
      }.freeze
      DEFAULT_TABLES = {
        'versions' => %w[
          salesforce_syncs versions tracked_workflows workflow_events
          workflow_steps workflow_transactions
        ],
        'datawarehouse' => %w[
          custom_question_answers disbursements line_item_order_rollups line_items
          nonprofit_category_reports nonprofit_statuses nonprofit_users nonprofits
        ]
      }.freeze

      def on_send(node)
        check_join_or_reference(node) if JOIN_METHODS.include?(node.method_name)
        check_query_arguments(node) if QUERY_METHODS.include?(node.method_name)
      end

      def on_lvasgn(node)
        var_name, value = *node
        db = db_group_for_expr(value)
        db ? var_db_groups[var_name] = db : var_db_groups.delete(var_name)
      end

      def on_block(node)
        shadowed = {}
        block_param_names(node.arguments).each do |param|
          shadowed[param] = var_db_groups.delete(param) if var_db_groups.key?(param)
        end
        shadowed_stack << shadowed
      end

      def after_block(_node)
        shadowed = shadowed_stack.pop || {}
        shadowed.each { |param, db| var_db_groups[param] = db }
      end

      def on_def(_node)
        var_db_groups.clear
        shadowed_stack.clear
      end
      alias_method :on_defs, :on_def

      private

      def block_param_names(args_node)
        return [] unless args_node

        args_node.children.each_with_object([]) do |arg, names|
          names << arg.children.first if BLOCK_ARG_TYPES.include?(arg.type)
        end
      end

      def check_join_or_reference(node)
        source_db = db_group_for_expr(node.receiver)
        node.arguments.each do |arg|
          check_assoc_arg(arg, source_db)
          if SQL_JOIN_METHODS.include?(node.method_name)
            check_sql_arg(arg, source_db, from_clause: node.method_name == :from)
          end
        end
      end

      def check_assoc_arg(node, source_db)
        each_assoc_symbol(node) do |sym_node, name|
          target_db = non_primary_associations[name]
          next unless target_db && source_db != target_db

          add_offense(
            sym_node,
            message: format(MSG_ASSOC, target: name, target_db:,
                                       source_db: source_db || :primary)
          )
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
        return unless node.str_type? || node.dstr_type?

        effective_source = source_db || :primary
        check_interpolated_models(node, effective_source) if node.dstr_type?
        sql_tables_in(node, from_clause:).each do |table|
          check_sql_table(node, table, effective_source)
        end
      end

      def check_interpolated_models(node, source_db)
        node.children.each do |child|
          send_node = interpolated_table_name_send(child)
          next unless send_node

          target_db = const_db_group(send_node.receiver)
          next unless target_db && target_db != source_db

          target = full_const_name(send_node.receiver)
          report_sql(node, target, target_db, source_db)
        end
      end

      def check_sql_table(node, table, source_db)
        return if SQL_KEYWORDS.include?(table.downcase)

        dbs = table_dbs(table)
        return unless dbs&.none?(source_db)

        report_sql(node, table, dbs.first, source_db)
      end

      def table_dbs(table)
        table_ownership[table]
      end

      def table_ownership
        @table_ownership ||= begin
          ownership = non_primary_tables.transform_values do |dbs|
            dbs.include?(:datawarehouse) ? dbs | Set[:primary] : dbs.dup
          end
          model_db_groups.each do |model_name, db|
            table = model_to_table_name(model_name)
            ownership[table] ||= Set.new
            ownership[table] << db
          end
          ownership
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
        return word if word.end_with?('s') && !word.end_with?('ss', 'us')
        return "#{word[0..-2]}ies" if word.match?(/[^aeiou]y\z/)
        return "#{word}es" if word.end_with?('s', 'x', 'z', 'ch', 'sh')

        "#{word}s"
      end

      def report_sql(node, target, target_db, source_db)
        add_offense(node, message: format(MSG_SQL, target:, target_db:, source_db:))
      end

      def sql_tables_in(node, from_clause: false)
        text = (node.str_type? ? node.value : dstr_static_sql(node)).gsub(EXTRACT_PATTERN, '')
        tables = text.scan(SQL_TABLE_PATTERN).flatten
        tables.concat(text.scan(FROM_LEADING_TABLE_PATTERN).flatten) if from_clause
        tables.uniq
      end

      def dstr_static_sql(node)
        node.children.map { |child| child.str_type? ? child.value : INTERPOLATED_PLACEHOLDER }.join
      end

      def interpolated_table_name_send(node)
        return nil unless node.begin_type?

        inner = node.children.first
        return nil unless inner&.send_type? && inner.method_name == :table_name
        return nil unless inner.receiver&.const_type?

        inner
      end

      def check_query_arguments(node)
        source_db = db_group_for_expr(node.receiver)
        node.arguments.each do |arg|
          if source_db
            if SQL_QUERY_METHODS.include?(node.method_name)
              check_sql_arg(arg, source_db, from_clause: node.method_name == :from)
            end
            check_mixed_arel_or_subquery(arg, source_db)
          else
            check_mixed_arel_tables(arg)
          end
        end
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

      def check_mixed_arel_or_subquery(node, source_db)
        return unless node.is_a?(Parser::AST::Node)
        return if materializing_send?(node)

        if (match = cross_db_ref(node, source_db))
          target, target_db = match
          add_offense(node, message: format(MSG_AREL, target:, target_db:, source_db:))
          return
        end

        node.children.each { |child| check_mixed_arel_or_subquery(child, source_db) }
      end

      def materializing_send?(node)
        node.send_type? && MATERIALIZING_METHODS.include?(node.method_name)
      end

      def cross_db_ref(node, source_db)
        return lvar_cross_db_ref(node, source_db) if node.lvar_type?
        return const_cross_db_ref(node, source_db) if node.send_type?

        nil
      end

      def lvar_cross_db_ref(node, source_db)
        name = node.children.first
        db = var_db_groups[name]
        [name, db] if db && db != source_db
      end

      def const_cross_db_ref(node, source_db)
        const_node = node.receiver
        return nil unless const_node&.const_type?

        db = const_db_group(const_node)
        [full_const_name(const_node), db] if db && db != source_db
      end

      def db_group_for_expr(node)
        return nil unless node.is_a?(Parser::AST::Node)

        if node.lvar_type?
          var_db_groups[node.children.first]
        elsif node.const_type?
          const_db_group(node)
        elsif node.send_type?
          db_group_for_send(node)
        end
      end

      def db_group_for_send(node)
        return nil if MATERIALIZING_METHODS.include?(node.method_name)

        non_primary_associations[node.method_name.to_s] || db_group_for_expr(node.receiver)
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

      def shadowed_stack
        @shadowed_stack ||= []
      end

      def model_db_groups
        GLRubocop::Helpers::ActiveRecordModelRegistry.database_groups_for(
          project_root: RuboCop::ConfigFinder.project_root,
          globs: model_globs,
          non_primary_base_classes: cop_config.fetch('NonPrimaryBaseClasses', DEFAULT_BASE_CLASSES),
          non_primary_models: cop_config.fetch('NonPrimaryModels', DEFAULT_MODELS)
        )
      end

      def model_globs
        cop_config.fetch('ModelGlobs', GLRubocop::Helpers::ActiveRecordModelRegistry::ALL_MODEL_GLOBS)
      end

      def non_primary_associations
        @non_primary_associations ||= invert_db_map(
          cop_config.fetch('NonPrimaryAssociations', DEFAULT_ASSOCIATIONS)
        )
      end

      def non_primary_tables
        @non_primary_tables ||= invert_db_set_map(
          cop_config.fetch('NonPrimaryTables', DEFAULT_TABLES)
        )
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
