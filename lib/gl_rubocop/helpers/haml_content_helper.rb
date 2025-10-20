module GLRubocop
  module HamlContentHelper
    def haml_file?
      file_path = processed_source.file_path
      file_path&.end_with?('.html.haml') && File.exist?(file_path)
    end

    def read_haml_file
      File.read(processed_source.file_path)
    rescue StandardError
      nil
    end
  end
end
