# frozen_string_literal: true

require_relative '../helpers/erb_content_helper'

module GLRubocop
  module GLCops
    # Ensures that simple variable references inside text-containing HTML
    # elements in ERB files are named with a _text or _content suffix (or
    # are exactly `text` or `content`). This makes the intent explicit:
    # _text for plain strings, _content for text-or-HTML values.
    #
    # Configuration parameters that are not rendered as user-visible text
    # (e.g. variant, size, href) belong in non-text elements and are exempt.
    #
    # Good:
    #   <p><%= @message_text %></p>
    #   <span><%= @banner_content %></span>
    #   <h1><%= text %></h1>
    #   <p class="<%= @variant %>"><%= @label_text %></p>   (variant is in attribute, not body)
    #
    # Bad:
    #   <p><%= @message %></p>
    #   <span><%= @title %></span>
    class TextAndContentVariableNaming < RuboCop::Cop::Cop
      include GLRubocop::ErbContentHelper

      MSG = '`%<name>s` is rendered inside a text element. ' \
            'Rename it with a `_text` suffix (plain text) or `_content` suffix (HTML content).'

      TEXT_TAGS = %w[
        a span strong em b i p
        h1 h2 h3 h4 h5 h6
        blockquote li td th
        label button dt dd caption
      ].freeze

      # Matches only bare variable/ivar references: <%= @name %> or <%= name %>
      # Does NOT match method calls with arguments (t('key'), helper.method, etc.)
      BARE_VAR_PATTERN = /<%=\s*@?(\w+)\s*%>/

      def investigate(processed_source)
        return unless erb_file?

        content = read_erb_file
        return unless content

        find_and_report_improperly_named_variables(content, processed_source)
      end

      private

      def find_and_report_improperly_named_variables(content, processed_source)
        TEXT_TAGS.each do |tag|
          pattern = element_pattern(tag)
          content.scan(pattern) do |groups|
            body = groups[0]

            body.scan(BARE_VAR_PATTERN) do |var_match|
              var_name = var_match[0]
              next if properly_named?(var_name)

              range = processed_source.buffer.source_range
              add_offense(nil, location: range, message: format(MSG, name: var_name))
            end
          end
        end
      end

      # Matches <tag ...attrs...>body</tag> where attrs may contain ERB expressions.
      def element_pattern(tag)
        Regexp.new(
          "<#{Regexp.escape(tag)}\\b(?:[^>]|<%.*?%>)*>(.*?)<\\/#{Regexp.escape(tag)}>",
          Regexp::MULTILINE | Regexp::IGNORECASE
        )
      end

      def properly_named?(name)
        name == 'text' || name == 'content' ||
          name.end_with?('_text', '_content')
      end
    end
  end
end
