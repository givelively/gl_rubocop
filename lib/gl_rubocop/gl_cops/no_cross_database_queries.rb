# frozen_string_literal: true

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
        count size length exists? empty? any? none? table_name
      ].freeze
      ASSOC_CONTAINER_TYPES = %i[array hash pair].freeze
      SQL_TABLE_PATTERN = /\b(?:JOIN|FROM)\s+"?([a-z_][a-z0-9_]*)"?/i

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

      def on_def(_node)
        var_db_groups.clear
      end
      alias_method :on_defs, :on_def

      private

      def check_join_or_reference(node)
        source_db = db_group_for_expr(node.receiver)
        node.arguments.each do |arg|
          check_assoc_arg(arg, source_db)
          check_sql_arg(arg, source_db) if SQL_JOIN_METHODS.include?(node.method_name)
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

      def check_sql_arg(node, source_db)
        return unless node.str_type? || node.dstr_type?

        sql_tables_in(node).each { |table| check_sql_table(node, table, source_db) }
      end

      def check_sql_table(node, table, source_db)
        target_db = non_primary_tables[table]
        if target_db && source_db != target_db
          report_sql(node, table, target_db, source_db || :primary)
        elsif non_primary_mismatch?(source_db, target_db)
          report_sql(node, table, :primary, source_db)
        end
      end

      def non_primary_mismatch?(source_db, target_db)
        source_db && source_db != :primary && target_db != source_db
      end

      def report_sql(node, target, target_db, source_db)
        add_offense(node, message: format(MSG_SQL, target:, target_db:, source_db:))
      end

      def sql_tables_in(node)
        text = node.str_type? ? node.value : dstr_static_sql(node)
        text.scan(SQL_TABLE_PATTERN).flatten.uniq
      end

      def dstr_static_sql(node)
        node.children.map do |child|
          child.str_type? ? child.value : interpolated_table_placeholder(child)
        end.join(' ')
      end

      def interpolated_table_placeholder(node)
        send_node = interpolated_table_name_send(node)
        return '' unless send_node

        db = const_db_group(send_node.receiver)
        return 'primary_table' if db == :primary

        tables_for(db).first.to_s
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
            check_sql_arg(arg, source_db) if SQL_QUERY_METHODS.include?(node.method_name)
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
        return model_db_groups[name] if model_db_groups.key?(name)
        return nil if anchored_at_cbase?(const_node)

        enclosing_namespaces(const_node).each do |ns|
          candidate = "#{ns}::#{name}"
          return model_db_groups[candidate] if model_db_groups.key?(candidate)
        end
        nil
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
        @non_primary_tables ||= invert_db_map(
          cop_config.fetch('NonPrimaryTables', DEFAULT_TABLES)
        )
      end

      def tables_for(db)
        return [] unless db

        cop_config.fetch('NonPrimaryTables', DEFAULT_TABLES).fetch(db.to_s, [])
      end

      def invert_db_map(mapping)
        mapping.each_with_object({}) do |(db, items), result|
          Array(items).each { |item| result[item.to_s] = db.to_sym }
        end
      end
    end
  end
end
