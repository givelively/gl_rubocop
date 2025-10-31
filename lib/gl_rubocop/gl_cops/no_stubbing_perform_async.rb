module GLRubocop
  module GLCops
    # This cop ensures that you don't stub perform_async. Stubbing prevents seeing errors from
    # invalid argumens - because sidekiq arguments have to be valid JSON data types:
    # github.com/sidekiq/sidekiq/wiki/Best-Practices#1-make-your-job-parameters-small-and-simple
    #
    # Good:
    #   expect(ExampleWorker).to have_enqueued_sidekiq_job

    #
    # Bad:
    #   allow(ExampleWorker).to receive(:perform_async)
    #   expect(ExampleWorker).to receive(:perform_async)
    #   expect(SomeWorker).not_to have_received(:perform_in)
    class NoStubbingPerformAsync < RuboCop::Cop::Cop
      MSG = "Don't stub perform async. Use the rspec-sidekick matchers instead: " \
            'expect(JobClass).to have_enqueued_sidekiq_job'.freeze

      # Match have_received with perform_async or perform_in
      def_node_matcher :have_received_perform?, <<~PATTERN
        (send nil? :have_received (sym {:perform_async :perform_in}) ...)
      PATTERN

      # Match receive with perform_async or perform_in
      def_node_matcher :receive_perform?, <<~PATTERN
        (send nil? :receive (sym {:perform_async :perform_in}) ...)
      PATTERN

      def on_send(node)
        return unless have_received_perform?(node) || receive_perform?(node)

        # Find the expect or allow context
        offense_node = find_offense_node(node)
        add_offense(offense_node) if offense_node
      end

      private

      def find_offense_node(node)
        current = node.parent
        while current
          return current if rspec_stubbing?(current)

          current = current.parent
        end
        nil
      end

      def rspec_stubbing?(node)
        return false unless node.send_type?
        return false unless %i[to not_to to_not].include?(node.method_name)

        receiver = node.receiver
        return false unless receiver&.send_type?

        %i[allow expect].include?(receiver.method_name)
      end
    end
  end
end
