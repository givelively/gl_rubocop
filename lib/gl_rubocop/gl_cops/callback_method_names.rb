# rubocop:disable I18n/RailsI18n/DecorateString
module GLRubocop
  module GLCops
    # This cop ensures that controller callbacks are named methods, not inline blocks.
    #
    # Good:
    #   before_action :set_user
    #
    # Bad:
    #   before_action { do_something }
    #   before_action -> { do_something }
    class CallbackMethodNames < RuboCop::Cop::Cop
      CALLBACKS = %i[before_action after_action around_action].freeze

      def on_send(node)
        return unless CALLBACKS.include?(node.method_name)

        error_message = 'Use a named method for controller callbacks instead of an inline block.'

        add_offense(node, message: error_message) if node.parent&.block_type?
      end
    end
  end
end
# rubocop:enable I18n/RailsI18n/DecorateString
