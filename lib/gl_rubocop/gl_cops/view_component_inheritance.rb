module GLRubocop
  module GLCops
    # This cop checks that all ViewComponent classes inherit from an allowlisted base class.
    #
    # Good:
    #   class ApplicationViewComponent < ViewComponent::Base
    #   end
    #
    #   class ApplicationViewComponentPreview < ViewComponent::Preview
    #   end
    #
    #   class Components::HeroComponent < ApplicationViewComponent
    #   end
    #
    #   class Components::CardComponentPreview < ApplicationViewComponentPreview
    #   end
    #
    #   class SomeHelperClass < SomeOtherClass
    #   end
    #
    # Bad:
    #   class Components::HeroComponent
    #   end
    #
    #   class Components::CardComponent < ViewComponent::Base
    #   end
    #
    #   class Components::CardComponentPreview < ViewComponent::Preview
    #   end
    #
    #   class Components::CardComponentPreview
    #   end
    class ViewComponentInheritance < RuboCop::Cop::Base
      COMPONENT_MSG = 'ViewComponents must inherit from ApplicationViewComponent'.freeze
      PREVIEW_MSG = 'ViewComponentPreviews must inherit from ApplicationViewComponentPreview'.freeze

      def on_class(node)
        parent = node.parent_class&.const_name
        class_name = node.identifier.const_name

        if class_name.end_with?('ComponentPreview')
          return true if component_preview_valid?(parent, class_name)

          add_offense(node, message: PREVIEW_MSG)
        elsif class_name.end_with?('Component')
          return true if component_valid?(parent, class_name)

          add_offense(node, message: COMPONENT_MSG)
        else
          true
        end
      end

      def component_preview_valid?(parent, class_name)
        class_name == 'ApplicationViewComponentPreview' ||
          parent == 'ApplicationViewComponentPreview'
      end

      def component_valid?(parent, class_name)
        class_name == 'ApplicationViewComponent' ||
          parent == 'ApplicationViewComponent'
      end
    end
  end
end
