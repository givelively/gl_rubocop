module Custom
  class PreventErbFiles < RuboCop::Cop::Cop
    MSG = 'File name should not end with .erb'.freeze

    def investigate(processed_source)
      file_path = processed_source.buffer.name
      return unless File.extname(file_path) == '.erb'

      range = processed_source.buffer.source_range
      add_offense(nil, location: range, message: MSG)
    end
  end
end