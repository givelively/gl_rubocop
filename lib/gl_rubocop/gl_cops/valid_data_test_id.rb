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
      INVALID_PATTERNS = [
        # HTML-style: data-testid="value"
        /\bdata-testid\s*=/i,
        /\bdata-testId\s*=/,
        /\bdata_test_id\s*=/,
        /\bdataTestId\s*=/,
        # HAML/Ruby hash-style: "data-testid": "value" or data_testid: "value"
        /"data-testid"\s*:/i,
        /"data-testId"\s*:/,
        /"dataTestId"\s*:/,
        /\bdata_testid\s*:/i,
        /\bdata_test_id\s*:/,
        /\bdataTestId\s*:/
      ].freeze

      def on_send(node)
        return unless haml_file? || erb_file?

        content = haml_file? ? read_haml_file : read_erb_file
        return unless content

        check_content(content, node)
      end

      def on_str(node)
        return unless node.str_type?

        check_string_content(node.value, node)
      end

      private

      def check_content(content, node)
        INVALID_PATTERNS.each do |pattern|
          next unless content.match?(pattern)

          match = content.match(pattern)
          invalid_attr = match[0].split(/[=:]/).first.gsub(/["']/, '')
          add_offense(
            node,
            message: format(MSG, invalid: invalid_attr)
          )
          break
        end
      end

      def check_string_content(content, node)
        INVALID_PATTERNS.each do |pattern|
          next unless content.match?(pattern)

          match = content.match(pattern)
          invalid_attr = match[0].split(/[=:]/).first.gsub(/["']/, '')
          add_offense(
            node,
            message: format(MSG, invalid: invalid_attr)
          )
          break
        end
      end
    end
  end
end
