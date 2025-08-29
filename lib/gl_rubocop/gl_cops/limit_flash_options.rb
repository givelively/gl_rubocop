# frozen_string_literal: true

module GLRubocop
  module GLCops
    class LimitFlashOptions < RuboCop::Cop::Base
      # This cop ensures that the use of any of our notification methods only accept the allowed keys for type
      # and variant.
      # Good:
      #   flash[:success] = "Operation successful"
      #   flash.now[:info] = "This is an info message"
      #   Alert::Component.new(type: :success, message: "Success")
      #   Notifications::Dismissible::Component.new(variant: :info, message: "Info")

      # Bad:
      #   flash[:error] = "Not allowed"
      #   flash.now[:anything_else] = "Not allowed"
      #   Alert::Component.new(type: :notice, message: "Error")
      #   Notifications::Dismissible::Component.new(variant: :blue_box, message: "Error")
      ALLOWED_FLASH_KEYS = %i[success info warning danger].freeze

      # Matches the Rails flash hash assignment
      def_node_matcher :rails_flash?, <<~PATTERN
        {
          (send
            (send nil? :flash) :[]=
            (sym $_)
            _*
          )
          (send
            (send
              (send nil? :flash) :now) :[]=
              (sym $_)
              _*
            )
        }
      PATTERN

      def_node_matcher :alert_component_new?, <<~PATTERN
        (send
          (const
            (const nil? :Alert) :Component) :new
          (hash
            (pair (sym :type) (sym $_)) _*
          )
        )
      PATTERN

      def_node_matcher :notifications_dismissible_component_new?, <<~PATTERN
        (send
          (const
            (const
              (const nil? :Notifications) :Dismissible
            ) :Component
          ) :new
          (hash
            (pair (sym :variant) (sym $_))
            (...)
          )
        )
      PATTERN

      # Checks for usage of flash or flash.now with keys not in the allowlist
      def on_send(node)
        check_key(node, rails_flash?(node))
        check_key(node, alert_component_new?(node))
        check_key(node, notifications_dismissible_component_new?(node))
      end

      def check_key(node, key)
        return false unless key
        return false if ALLOWED_FLASH_KEYS.include?(key)

        add_offense(
          node,
          message: "'#{key}' is not one of the permitted flash keys: #{ALLOWED_FLASH_KEYS}"
        )
      end
    end
  end
end
