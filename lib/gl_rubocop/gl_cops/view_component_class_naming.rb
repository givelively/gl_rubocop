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
      def on_class(node)
        class_name = node.identifier.const_name
        return true if class_name == 'Component'
        return true if class_name == 'ApplicationViewComponent'

        add_offense(node, message: 'ViewComponent class names must be "Component".')
      end
    end
  end
end