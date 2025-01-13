module GLRubocop
  module GLCops
    class ViewComponentDataTestIds < RuboCop::Cop::Cop

      puts "Loading ViewComponentDataTestIds cop!"

      MSG = 'View components must include a data-test-id attribute'

      def initialize(*)
        puts "Initializing ViewComponentDataTestIds cop!"
        super
      end

      def on_new_investigation
        puts "\nInvestigating file..."
        puts "File path: #{processed_source.file_path}"
        puts "File extension: #{File.extname(processed_source.file_path)}"
        puts "File exists? #{File.exist?(processed_source.file_path)}"
        puts "Raw source: #{processed_source.raw_source}"
        
        # Read the file directly
        if File.exist?(processed_source.file_path)
          raw_content = File.read(processed_source.file_path)
          puts "\nActual file contents:"
          puts raw_content
          
          puts "\nLine by line analysis:"
          raw_content.lines.each_with_index do |line, index|
            puts "Line #{index + 1}: #{line.inspect}"
            if line.strip.start_with?('%div')
              puts "Found div tag at line #{index + 1}"
              if !line.include?('data-test-id')
                puts "Missing data-test-id attribute!"
                add_offense(line, location: processed_source.buffer.source_range, message: MSG)
              end
            end
          end
        end               
      end

      private
    end
  end
end
