module GLRubocop
  module GLCops
    class UniqueIdentifier < RuboCop::Cop::Base
      # This cop ensures that view components include a data-test-id attribute.
      #
      # Good:
      #   data-test-id="unique-id"
      #
      # Bad:
      #   data-testid="unique-id"
      #   data-testId="unique-id"
      #   data-test_id="unique-id"
      MSG = 'View components must include a data-test-id attribute'.freeze
      EMPTY_MSG = 'data-test-id attribute must not be empty'.freeze
      UNIQUE_IDENTIFIER = 'data-test-id='.freeze

      def on_send(node)
        return unless file_exists? && valid_file_name? && valid_method_name?(node)

        return add_offense(node) unless raw_content.include?(UNIQUE_IDENTIFIER)

        add_offense(node, message: EMPTY_MSG) if test_id_value.strip.empty?
      end

      private

      def file_exists?
        File.exist?(processed_source.file_path)
      end

      def valid_file_name?
        File.basename(processed_source.file_path) == 'component.html.erb'
      end

      def identifiable_line
        line_number = raw_content.lines.find_index { |line| line.include?(UNIQUE_IDENTIFIER) }
        raw_content.lines[line_number]
      end

      def raw_content
        @raw_content ||= File.read(processed_source.file_path)
      end

      def test_id_value
        str_match = identifiable_line[/data-test-id=('|")[^'|"]*/]

        return '' unless str_match

        str_match.gsub(/data-test-id=./, '')
      end

      def valid_method_name?(node)
        node.method_name == :render || node.method_name == :template
      end
    end
  end
end
