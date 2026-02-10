# frozen_string_literal: true

require_relative '../helpers/haml_content_helper'
require_relative '../helpers/erb_content_helper'

module GLRubocop
  module GLCops
    class ValidDataTestId < RuboCop::Cop::Cop
      include GLRubocop::HamlContentHelper
      include GLRubocop::ErbContentHelper

      MSG = 'Use data-test-id instead of %<invalid>s'

      # Invalid variations of data-test-id
      # Matches: data-testid, data_test_id, datatestid, dataTestId, etc.
      # Does NOT match: data-test-id (the valid format)
      INVALID_PATTERN = /\bdata(?!-test-id\b)[-_]?test[-_]?id\b/i

      def investigate(processed_source)
        return unless haml_file? || erb_file?

        content = haml_file? ? read_haml_file : read_erb_file
        return unless content

        check_file_content(content, processed_source)
      end

      def on_str(node)
        return unless node.str_type?

        check_string_content(node.value, node)
      end

      private

      def check_file_content(content, processed_source)
        return unless content.match?(INVALID_PATTERN)

        match = content.match(INVALID_PATTERN)
        invalid_attr = match[0].split(/[=:]/).first.gsub(/["']/, '')
        range = processed_source.buffer.source_range
        add_offense(
          nil,
          location: range,
          message: format(MSG, invalid: invalid_attr)
        )
      end

      def check_string_content(content, node)
        return unless content.match?(INVALID_PATTERN)

        match = content.match(INVALID_PATTERN)
        invalid_attr = match[0].split(/[=:]/).first.gsub(/["']/, '')
        add_offense(
          node,
          message: format(MSG, invalid: invalid_attr)
        )
      end
    end
  end
end
