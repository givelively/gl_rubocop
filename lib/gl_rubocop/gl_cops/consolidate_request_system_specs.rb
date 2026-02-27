# rubocop:disable I18n/RailsI18n/DecorateString
# frozen_string_literal: true

module GLRubocop
  module GLCops
    # This cop ensures that request and system specs consolidate examples in a single it block.
    #
    # Good:
    #   RSpec.describe UsersController, type: :request do
    #     describe 'GET /users' do
    #       it 'returns users' do
    #         get users_path
    #         expect(response).to be_successful
    #       end
    #     end
    #   end
    #
    # Bad:
    #   RSpec.describe UsersController, type: :request do
    #     describe 'GET /users' do
    #       it 'returns success' do
    #         get users_path
    #         expect(response).to be_successful
    #       end
    #
    #       it 'returns json' do
    #         get users_path
    #         expect(response.content_type).to eq('application/json')
    #       end
    #     end
    #   end
    class ConsolidateRequestSystemSpecs < RuboCop::Cop::Cop
      MSG = 'Consolidate examples with the same setup in request specs and system specs. ' \
            'Use a single it block instead of multiple it blocks.'

      RSPEC_EXAMPLE_METHODS = %i[it specify example].freeze
      RSPEC_GROUP_METHODS = %i[describe context].freeze

      def on_block(node)
        return unless rspec_group?(node)

        # Check if this block or any parent has type: :request or type: :system
        return unless request_or_system_spec?(node)

        check_multiple_examples(node)
      end

      private

      def rspec_group?(node)
        return false unless node.send_node.send_type?

        RSPEC_GROUP_METHODS.include?(node.send_node.method_name)
      end

      def request_or_system_spec?(node)
        # Check current node and walk up to find type metadata
        current = node
        while current
          return true if current.block_type? && request_or_system_type?(current)

          current = current.parent
        end

        false
      end

      # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      def request_or_system_type?(node)
        return false unless node.send_node.send_type?

        types = %i[request system]

        node.send_node.arguments.each do |arg|
          next unless arg.hash_type?

          arg.pairs.each do |pair|
            next unless pair.key.sym_type? && pair.key.value == :type

            value = pair.value
            return true if value.sym_type? && types.include?(value.value)
          end
        end

        false
      end
      # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

      def check_multiple_examples(node)
        example_blocks = find_example_blocks(node)
        return if example_blocks.size <= 1

        # Add offense to the second example block onwards
        example_blocks[1..].each do |example_node|
          add_offense(example_node, message: MSG)
        end
      end

      def find_example_blocks(node)
        body = node.body
        return [] unless body

        # If body is a begin node (multiple children), get blocks from it
        # Otherwise, check if the single child is a block
        children = body.begin_type? ? body.children : [body]

        children.select do |child|
          child.block_type? &&
            child.send_node.send_type? &&
            RSPEC_EXAMPLE_METHODS.include?(child.send_node.method_name)
        end
      end
    end
  end
end
# rubocop:enable I18n/RailsI18n/DecorateString
