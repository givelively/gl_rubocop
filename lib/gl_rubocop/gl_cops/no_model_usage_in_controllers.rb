require_relative '../helpers/active_record_model_registry'

module GLRubocop
  module GLCops
    # This cop bans direct ActiveRecord model usage (queries, persistence, and CRUD)
    # inside controllers.
    #
    # Per our controller standards RFC, calling model methods directly in a controller
    # entangles the networking/HTTP layer with the data layer. Query and persistence
    # logic belongs in a GLCommand.
    #
    # Only constants confirmed (by scanning the app's model files) to transitively
    # inherit from ApplicationRecord/ActiveRecord::Base are flagged, so plain Ruby
    # objects that happen to live under app/models (wrappers, value objects, etc.) are
    # not flagged.
    #
    # Good:
    #   result = FindNonprofit.call(id: params[:id])
    #
    # Bad:
    #   nonprofit = Nonprofit.find(params[:id])
    #   nonprofit.update!(name: params[:name])
    class NoModelUsageInControllers < RuboCop::Cop::Base
      MSG = 'Do not use the `%<model>s` model directly in a controller. Move this ' \
            'logic into a GLCommand.'.freeze

      CLASS_LEVEL_METHODS = %i[
        find find_by find_by! find_or_create_by find_or_create_by!
        where create create! new all order includes joins pluck
        exists? count first last update_all destroy_all
      ].freeze

      INSTANCE_LEVEL_METHODS = %i[save save! update update! destroy destroy!].freeze

      def on_send(node)
        receiver = node.receiver
        return unless receiver

        if receiver.const_type?
          check_class_level_usage(node, receiver)
        elsif receiver.lvar_type?
          check_instance_level_usage(node, receiver)
        end
      end

      def on_lvasgn(node)
        var_name, value = *node
        model_vars[var_name] = model_name_for(value.receiver) if assigns_model?(value)
      end

      def on_def(_node)
        model_vars.clear
      end
      alias_method :on_defs, :on_def

      private

      def check_class_level_usage(node, receiver)
        return unless CLASS_LEVEL_METHODS.include?(node.method_name)

        model = model_name_for(receiver)
        return unless model

        add_offense(node, message: format(MSG, model:))
      end

      def check_instance_level_usage(node, receiver)
        return unless INSTANCE_LEVEL_METHODS.include?(node.method_name)

        model = model_vars[receiver.node_parts.first]
        return unless model

        add_offense(node, message: format(MSG, model:))
      end

      def assigns_model?(value)
        value.respond_to?(:send_type?) && value.send_type? && value.receiver&.const_type?
      end

      def model_name_for(const_node)
        name = full_const_name(const_node)
        name if model_names.include?(name)
      end

      def full_const_name(node)
        return nil unless node&.const_type?

        namespace, name = *node
        [namespace && full_const_name(namespace), name].compact.join('::')
      end

      def model_vars
        @model_vars ||= {}
      end

      def model_names
        GLRubocop::Helpers::ActiveRecordModelRegistry.for(project_root:,
                                                          globs: model_globs)
      end

      def project_root
        RuboCop::ConfigFinder.project_root
      end

      def model_globs
        cop_config.fetch('ModelGlobs', GLRubocop::Helpers::ActiveRecordModelRegistry::DEFAULT_GLOBS)
      end
    end
  end
end
