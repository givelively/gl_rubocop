module GLRubocop
  module GLCops
    class UniqueIdentifier < RuboCop::Cop::Base
      MSG = 'View components must include a data-test-id attribute'
      EMPTY_MSG = 'data-test-id attribute must not be empty'
      UNIQUE_IDENTIFIER = 'data-test-id'

      def on_send(node)
        return unless %i[render template].include?(node.method_name)
        return unless File.exist?(processed_source.file_path)
        
        raw_content = File.read(processed_source.file_path)
        return add_offense(node) unless raw_content.include?(UNIQUE_IDENTIFIER)

        line_number = raw_content.lines.find_index { |line| line.include?(UNIQUE_IDENTIFIER) }
        line = raw_content.lines[line_number]
        
        test_id_value = line.match(/#{Regexp.quote(UNIQUE_IDENTIFIER)}:\s*["']([^"']*)["']/)[1]
        add_offense(node, message: EMPTY_MSG) if test_id_value.strip.empty?
      end
    end
  end
end
