# frozen_string_literal: true

module GLRubocop
  module GLCops
    # This cop ensures that VCR cassettes have names.
    #
    # Good:
    #   VCR.use_cassette('cassette_name') { ... }
    #   VCR.use_cassette("cassette_name") { ... }
    #
    # Bad:
    #   VCR.use_cassette { ... }
    #   VCR.use_cassette() { ... }
    class VcrCassetteNames < RuboCop::Cop::Cop
      MSG = 'VCR cassettes must have a name. Example: VCR.use_cassette("cassette_name") { ... }'

      def_node_matcher :vcr_use_cassette?, <<~PATTERN
        (send (const nil? :VCR) :use_cassette ...)
      PATTERN

      def on_send(node)
        return unless vcr_use_cassette?(node)
        return if has_cassette_name?(node)

        add_offense(node, message: MSG)
      end

      private

      def has_cassette_name?(node)
        # Check if the first argument exists and is a string
        return false if node.arguments.empty?

        first_arg = node.arguments.first
        first_arg.str_type? || first_arg.dstr_type?
      end
    end
  end
end
