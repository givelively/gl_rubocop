# frozen_string_literal: true

module GlRubocop
  module GlCops
    class LimitFlashOptions < RuboCop::Cop::Base
      MSG = 'This cop checks for the use of flash options not in the whitelist.' \
            'Please limit flash options to those defined in the application configuration.'

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

      # Checks for usage of flash or flash.now with keys not in the whitelist
      def on_send(node)
        check_rails_flash?(node)
        check_alert_component_new?(node)
        check_notifications_dismissable_component_new?(node)
      end

      def check_rails_flash?(node)
        key, _value = rails_flash?(node)
        return false unless key
        return false if ALLOWED_FLASH_KEYS.include?(key)

        add_offense(node, message: MSG)
      end

      def check_alert_component_new?(node)
        key = alert_component_new?(node)
        return false unless key

        return false if ALLOWED_FLASH_KEYS.include?(key)

        add_offense(node, message: MSG)
      end

      def check_notifications_dismissable_component_new?(node)
        key = notifications_dismissible_component_new?(node)
        return false unless key

        return false if ALLOWED_FLASH_KEYS.include?(key)

        add_offense(node, message: MSG)
      end
    end
  end
end
