# frozen_string_literal: true

require_relative '../helpers/erb_content_helper'

module GLRubocop
  module GLCops
    # Ensures that text-containing HTML elements in ERB files do not have
    # literal text outside of ERB expressions. All visible text must be
    # wrapped in <%= t() %> or a variable expression.
    #
    # Good:
    #   <p><%= t('components.message') %></p>
    #   <span><%= @label_text %></span>
    #   <h1><%= @title_text %></h1>
    #   <%= content_tag(:p, t('components.message')) %>
    #
    # Bad:
    #   <p>Hello World</p>
    #   <span>Click here</span>
    #   <h1>Page Title</h1>
    class NoHardcodedStringsInErbTextElements < RuboCop::Cop::Cop
      include GLRubocop::ErbContentHelper

      MSG = 'Hardcoded string in <%<tag>s> on line %<line>d. ' \
            'Use an i18n expression (t()) or a variable.'

      TEXT_TAGS = %w[
        a span strong em b i p
        h1 h2 h3 h4 h5 h6
        blockquote li td th
        label button dt dd caption
      ].freeze

      def investigate(processed_source)
        return unless erb_file?

        content = read_erb_file
        return unless content

        find_and_report_hardcoded_strings(content, processed_source)
      end

      private

      def find_and_report_hardcoded_strings(content, processed_source)
        TEXT_TAGS.each do |tag|
          pattern = element_pattern(tag)
          content.scan(pattern) do |groups|
            inner = groups[0]
            next unless hardcoded_text?(inner)

            match_start = Regexp.last_match.begin(0)
            line_number = content[0...match_start].count("\n") + 1
            range = processed_source.buffer.source_range
            add_offense(nil, location: range, message: format(MSG, tag: tag, line: line_number))
          end
        end
      end

      # Matches <tag ...attrs...>body</tag> where attrs may include ERB expressions.
      def element_pattern(tag)
        Regexp.new(
          "<#{Regexp.escape(tag)}\\b(?:[^>]|<%.*?%>)*>(.*?)<\\/#{Regexp.escape(tag)}>",
          Regexp::MULTILINE | Regexp::IGNORECASE
        )
      end

      def hardcoded_text?(inner_content)
        # Skip elements that contain child HTML tags — only flag leaf-level text
        # to avoid duplicate offenses on nested elements.
        return false if inner_content.match?(/<[a-z]/i)

        stripped = inner_content.gsub(/<%.*?%>/m, '')
        stripped.match?(/[[:alpha:]]/)
      end
    end
  end
end
