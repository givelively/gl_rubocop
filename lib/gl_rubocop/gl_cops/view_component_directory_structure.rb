module GLRubocop
  module GLCops
    # This cop checks that all ViewComponent classes inherit from an allowlisted base module.
    class ViewComponentDirectoryStructure < RuboCop::Cop::Base
      MSG = 'ViewComponent must belong to an allowed base module: %<allowed>s'.freeze
      ALLOWED_MODULES = %w[Core Admin NonprofitAdmin Packs].freeze

      def on_class(node)
        return true if node.identifier.const_name == 'ApplicationViewComponent'
        base_module = node.parent_module_name&.split('::')&.first
        return true if ALLOWED_MODULES.include?(base_module)

        add_offense(node, message: format(MSG, allowed: ALLOWED_MODULES.join(', ')))
      end
    end
  end
end
