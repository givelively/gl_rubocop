module GLRubocop
  module GLCops
    # This cop checks naming for classes inheriting from
    # ApplicationViewComponent or ApplicationViewComponentPreview.
    #
    # Good:
    #   class Component < ApplicationViewComponent
    #   end
    #
    #   class ComponentPreview < ApplicationViewComponentPreview
    #   end
    #
    # Bad:
    #   class UserCardComponent < ApplicationViewComponent
    #   end
    #
    #   class UserCardComponentPreview < ApplicationViewComponentPreview
    #   end
    class ViewComponentClassNaming < RuboCop::Cop::Base
      def on_class(node)
        parent_class = node.parent_class&.const_name
        if parent_class == 'ApplicationViewComponent'
          return if node.identifier.const_name == 'Component'

          add_offense(node, message: 'ViewComponent class names must be "Component".')
        end
        return unless parent_class == 'ApplicationViewComponentPreview'
        return if node.identifier.const_name == 'ComponentPreview'

        add_offense(node, message: 'ViewComponentPreview class names must be "ComponentPreview".')
      end
    end
  end
end
