module GLRubocop
  module GLCops
    # This cop checks that the class name is "Component" or "ApplicationViewComponent".
    #
    # Good:
    #   class Component < ViewComponent::Base
    #   end
    #
    #   class ApplicationViewComponent < ViewComponent::Base
    #   end
    #
    # Bad:
    #   class UserCardComponent < ViewComponent::Base
    #   end
    class ViewComponentClassNaming < RuboCop::Cop::Base
      ALLOWED_PARENT_CLASSES = %w[ViewComponent::Base ApplicationViewComponent].freeze

      def on_class(node)
        return unless ALLOWED_PARENT_CLASSES.include?(node.parent_class&.const_name)

        class_name = node.identifier.const_name
        return true if class_name == 'Component'
        return true if class_name == 'ApplicationViewComponent'

        add_offense(node, message: 'ViewComponent class names must be "Component".')
      end
    end
  end
end
