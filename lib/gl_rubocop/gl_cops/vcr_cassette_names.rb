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
    class VcrCassetteNames < RuboCop::Cop::Cop
      MSG = 'VCR cassettes must have a name. Example: VCR.use_cassette("cassette_name") { ... }'
      RSPEC_MSG = 'VCR cassettes must have a name. ' \
                  'Example: describe "test", vcr: { cassette_name: :my_cassette } do'

      RSPEC_METHODS = %i[describe context it specify example].freeze

      def_node_matcher :vcr_use_cassette?, <<~PATTERN
        (send (const nil? :VCR) :use_cassette ...)
      PATTERN

      def_node_matcher :rspec_vcr_symbol?, <<~PATTERN
        (sym :vcr)
      PATTERN

      def_node_matcher :rspec_vcr_hash?, <<~PATTERN
        (hash (pair (sym :vcr) $_))
      PATTERN

      def on_send(node)
        check_vcr_use_cassette(node)
        check_rspec_metadata(node)
      end

      private

      def check_vcr_use_cassette(node)
        return unless vcr_use_cassette?(node)
        return if cassette_name?(node)

        add_offense(node, message: MSG)
      end

      def check_rspec_metadata(node)
        return unless RSPEC_METHODS.include?(node.method_name)

        node.arguments.each do |arg|
          if rspec_vcr_symbol?(arg)
            add_offense(arg, message: RSPEC_MSG)
          elsif arg.hash_type?
            check_vcr_hash_metadata(arg)
          end
        end
      end

      def check_vcr_hash_metadata(hash_node)
        hash_node.pairs.each do |pair|
          next unless vcr_pair?(pair)

          add_offense(pair, message: RSPEC_MSG) unless valid_vcr_value?(pair.value)
        end
      end

      def vcr_pair?(pair)
        pair.key.sym_type? && pair.key.value == :vcr
      end

      def valid_vcr_value?(value)
        return false unless value.hash_type?

        value.pairs.any? do |inner_pair|
          inner_pair.key.sym_type? && inner_pair.key.value == :cassette_name
        end
      end

      def cassette_name?(node)
        # Check if the first argument exists and is a string
        return false if node.arguments.empty?

        first_arg = node.arguments.first
        first_arg.str_type? || first_arg.dstr_type?
      end
    end
  end
end
