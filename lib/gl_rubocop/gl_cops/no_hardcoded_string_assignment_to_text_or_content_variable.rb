# frozen_string_literal: true

module GLRubocop
  module GLCops
    # Ensures that variables and parameters named with _text, text, _content,
    # or content suffixes are never assigned a hardcoded string literal. Create an
    # i18n entry and use t() or I18n.t() instead.
    #
    # Good:
    #   title_text = t('components.title')
    #   @label_text = I18n.t('components.label')
    #   def initialize(button_text: t('components.button.default'))
    #   title_text = content_tag(:span, t('components.title'))
    #   @label_content = tag.p(t('components.label'), class: 'label')
    #
    # Bad:
    #   title_text = 'Hello'
    #   @label_text = 'Click here'
    #   def initialize(button_text: 'Submit')
    class NoHardcodedStringAssignmentToTextOrContentVariable < RuboCop::Cop::Cop
      MSG = '`%<name>s` must not be assigned a hardcoded string. ' \
            'Create an i18n entry and use t() instead.'

      def on_lvasgn(node)
        name, value = node.children
        return unless text_or_content_name?(name)
        return unless value&.str_type?

        add_offense(value, message: format(MSG, name:))
      end

      def on_ivasgn(node)
        name, value = node.children
        return unless text_or_content_name?(name.to_s.delete_prefix('@'))
        return unless value&.str_type?

        add_offense(value, message: format(MSG, name:))
      end

      def on_kwoptarg(node)
        name, default = node.children
        return unless text_or_content_name?(name)
        return unless default&.str_type?

        add_offense(default, message: format(MSG, name:))
      end

      private

      def text_or_content_name?(name)
        n = name.to_s
        n == 'text' || n == 'content' || n.end_with?('_text', '_content')
      end
    end
  end
end
