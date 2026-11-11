require 'prism'

module GLRubocop
  module Helpers
    # Parses Ruby source into a Parser-gem-compatible AST using Prism.
    #
    # The `parser` gem's `parser/current` only knows Ruby syntax up to 3.3 and
    # warns on newer Rubies. Prism's `ParserCurrent` covers 3.3 and up, but warns
    # on older Rubies, so on Ruby < 3.3 fall back to the 3.3 grammar, which
    # also accepts older syntax.
    module RubyParser
      PARSER =
        if Gem::Version.new(RUBY_VERSION) < Gem::Version.new('3.3')
          Prism::Translation::Parser33
        else
          Prism::Translation::ParserCurrent
        end

      module_function

      # Returns the AST, or nil when the file can't be parsed.
      def parse_file(path)
        PARSER.parse(File.read(path))
      rescue Parser::SyntaxError, EncodingError
        nil
      end
    end
  end
end
