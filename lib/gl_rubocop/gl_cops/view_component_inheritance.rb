module GLRubocop
  module GLCops
    # This cop checks that all ViewComponent classes inherit from an allowlisted base module.
    class ViewComponentInheritance < RuboCop::Cop::Base
      INHERITANCE_MSG = 'ViewComponent must inherit from ApplicationViewComponent'.freeze
      MODULE_NAME_MSG = 'ViewComponent must inherit from an allowed base module: %<allowed>s'.freeze
      ALLOWED_MODULES = %w[Core Admin NonprofitAdmin Packs SimpleWidget SmartDonations].freeze

      def on_class(node)
        parent = node.parent_class
        return true if inherits_from_application_view_component(node)

        add_offense(node, message: INHERITANCE_MSG)
      end

      private

      def inherits_from_application_view_component(node)
        parent = node.parent_class
        return false unless parent

        parent_name = parent.const_name
        parent_name == 'ApplicationViewComponent' || parent_name == 'ViewComponent::Base'
      end
    end
  end
end
