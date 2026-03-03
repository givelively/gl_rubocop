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
    class ConsolidateRequestSystemSpecs < RuboCop::Cop::Base
      MSG = 'Consolidate examples with the same setup in request specs and system specs. ' \
            'Use a single it block instead of multiple it blocks.'

      RSPEC_EXAMPLE_METHODS = %i[it specify example].freeze

      # @!method rspec_group?(node)
      def_node_matcher :rspec_group?, <<~PATTERN
        (block (send _ {:describe :context} ...) ...)
      PATTERN

      # @!method request_or_system_type?(node)
      def_node_matcher :request_or_system_type?, <<~PATTERN
        (block (send _ _ ... (hash <(pair (sym :type) (sym {:request :system})) ...>)) ...)
      PATTERN

      def on_new_investigation
        @spec_type_cache = {}
      end

      def on_block(node)
        return unless rspec_group?(node)
        return unless request_or_system_spec?(node)

        check_multiple_examples(node)
      end

      private

      def request_or_system_spec?(node)
        current = node
        while current
          if current.block_type?
            unless @spec_type_cache.key?(current)
              @spec_type_cache[current] =
                request_or_system_type?(current)
            end
            return true if @spec_type_cache[current]
          end
          current = current.parent
        end

        false
      end

      def check_multiple_examples(node)
        examples = find_example_blocks(node)
        return if examples.size <= 1

        examples[1..].each do |example_node|
          add_offense(example_node, message: MSG)
        end
      end

      def find_example_blocks(node)
        return [] unless node.body

        node.body.each_child_node(:block).select do |child|
          RSPEC_EXAMPLE_METHODS.include?(child.send_node.method_name)
        end
      end
    end
  end
end
