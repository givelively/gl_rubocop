module GLRubocop
  module ErbContentHelper
    def erb_file?
      processed_source.file_path&.end_with?('.erb', '.html.erb')
    end

    def read_erb_file
      return unless processed_source.file_path

      File.read(processed_source.file_path)
    rescue StandardError
      nil
    end
  end
end
