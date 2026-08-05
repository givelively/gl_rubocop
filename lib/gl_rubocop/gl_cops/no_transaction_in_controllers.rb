module GLRubocop
  module GLCops
    # This cop bans the use of ActiveRecord transactions within controllers.
    #
    # Per our controller standards RFC, opening a database transaction in a controller
    # entangles the networking layer with the database layer and violates separation of
    # concerns. Transactional logic belongs in a GLCommand or service object.
    #
    # Good:
    #   # app/commands/transfer_funds.rb
    #   ActiveRecord::Base.transaction do
    #     # ...
    #   end
    #
    # Bad:
    #   # app/controllers/transfers_controller.rb
    #   ActiveRecord::Base.transaction do
    #     # ...
    #   end
    class NoTransactionInControllers < RuboCop::Cop::Base
      MSG = 'Database transactions are not allowed in controllers. Move transactional ' \
            'logic into a GLCommand or service object.'.freeze

      # Matches `.transaction` called on a constant receiver, e.g.
      # ActiveRecord::Base.transaction, ApplicationRecord.transaction, SomeModel.transaction
      def_node_matcher :transaction_on_const?, <<~PATTERN
        (send (const ...) :transaction ...)
      PATTERN

      def on_send(node)
        return unless transaction_on_const?(node)

        add_offense(node)
      end
    end
  end
end
