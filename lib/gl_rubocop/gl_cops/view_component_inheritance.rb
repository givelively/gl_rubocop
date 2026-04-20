module GLRubocop
  module GLCops
    # This cop checks that all ViewComponent classes inherit from an allowlisted base class.
    #
    # Good:
    #   class Components::HeroComponent < ApplicationViewComponent
    #   end
    #
    #   class Components::CardComponent < ViewComponent::Base
    #   end
    #
    # Bad:
    #   class Components::HeroComponent < ViewComponent
    #   end
    #
    #   class Components::CardComponent
    #   end
    class ViewComponentInheritance < RuboCop::Cop::Base
      INHERITANCE_MSG = 'ViewComponent must inherit from ApplicationViewComponent'.freeze

      def on_class(node)
        return true if inherits_from_application_view_component(node)

        add_offense(node, message: INHERITANCE_MSG)
      end

      private

      def inherits_from_application_view_component(node)
        parent = node.parent_class
        return false unless parent

        parent_name = parent.const_name
        %w[ApplicationViewComponent ViewComponent::Base].include?(parent_name)
      end
    end
  end
end
