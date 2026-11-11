module GLRubocop
  module GLCops
    class PreventHamlFiles < RuboCop::Cop::Base
      MSG = 'File name should not end with .haml'.freeze

      def on_new_investigation
        file_path = processed_source.buffer.name
        return unless File.extname(file_path) == '.haml'

        range = processed_source.buffer.source_range
        add_offense(range, message: MSG)
      end
    end
  end
end
