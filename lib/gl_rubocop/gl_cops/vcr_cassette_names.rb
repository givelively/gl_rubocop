# frozen_string_literal: true

module GLRubocop
  module GLCops
    # This cop ensures that VCR cassettes have names.
    #
    # Good:
    #   VCR.use_cassette('cassette_name') { ... }
    #   VCR.use_cassette("cassette_name") { ... }
    #   describe '.create', vcr: { cassette_name: :chariot_connect_create } do
    #
    # Bad:
    #   VCR.use_cassette { ... }
    #   VCR.use_cassette() { ... }
    #   describe 'something', :vcr do
    class VcrCassetteNames < RuboCop::Cop::Base
      MSG = 'VCR cassettes must have a name. Example: VCR.use_cassette("cassette_name") { ... }'
      RSPEC_MSG = 'VCR cassettes must have a name. ' \
                  'Example: describe "test", vcr: { cassette_name: :my_cassette } do'

      RSPEC_METHODS = %i[describe context it specify example].freeze

      # @!method vcr_use_cassette?(node)
      def_node_matcher :vcr_use_cassette?, <<~PATTERN
        (send (const nil? :VCR) :use_cassette ...)
      PATTERN

      # @!method vcr_use_cassette_with_name?(node)
      def_node_matcher :vcr_use_cassette_with_name?, <<~PATTERN
        (send (const nil? :VCR) :use_cassette {str dstr} ...)
      PATTERN

      # @!method rspec_vcr_symbol?(node)
      def_node_matcher :rspec_vcr_symbol?, <<~PATTERN
        (sym :vcr)
      PATTERN

      # @!method vcr_hash_without_cassette_name?(node)
      def_node_matcher :vcr_hash_without_cassette_name?, <<~PATTERN
        (pair (sym :vcr) !{(hash <(pair (sym :cassette_name) _) ...>)})
      PATTERN

      def on_send(node)
        check_vcr_use_cassette(node)
        check_rspec_metadata(node)
      end

      private

      def check_vcr_use_cassette(node)
        return unless vcr_use_cassette?(node)
        return if vcr_use_cassette_with_name?(node)

        add_offense(node, message: MSG)
      end

      def check_rspec_metadata(node)
        return unless RSPEC_METHODS.include?(node.method_name)

        node.arguments.each do |arg|
          if rspec_vcr_symbol?(arg)
            add_offense(arg, message: RSPEC_MSG)
          elsif arg.hash_type?
            arg.pairs.each do |pair|
              add_offense(pair, message: RSPEC_MSG) if vcr_hash_without_cassette_name?(pair)
            end
          end
        end
      end
    end
  end
end
