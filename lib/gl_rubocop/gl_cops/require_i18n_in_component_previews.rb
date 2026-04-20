# frozen_string_literal: true

module GLRubocop
  module GLCops
    # This cop ensures that ViewComponent preview files use i18n helpers
    # instead of naked string literals.
    #
    # Good:
    #   def default(text: t('components.button.default'))
    #   render(Core::Button::Component.new(text: t('components.button.default')))
    #   render_with_template(template: 'core/alert/component_preview/default')
    #
    # Bad:
    #   def default(text: 'Default Button')
    #   render(Core::Button::Component.new(text: 'Default Button'))
    class RequireI18nInComponentPreviews < RuboCop::Cop::Cop
      MSG = 'Use i18n helpers (t() or I18n.t()) instead of naked strings in component previews.'

      def on_str(node)
        return if template_path?(node)
        return if i18n_key?(node)

        add_offense(node, message: MSG)
      end

      private

      def template_path?(node)
        parent = node.parent
        return false unless parent&.pair_type?

        key = parent.key
        key.sym_type? && key.value == :template
      end

      def i18n_key?(node)
        parent = node.parent
        return false unless parent&.send_type?

        i18n_send?(parent)
      end

      def i18n_send?(node)
        return true if node.method_name == :t && node.receiver.nil?
        return true if node.method_name == :t &&
                       node.receiver&.const_type? &&
                       node.receiver.short_name == :I18n

        false
      end
    end
  end
end
