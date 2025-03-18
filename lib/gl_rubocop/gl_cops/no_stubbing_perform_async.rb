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

      # This pattern captures expectations for perform_async and perform_in
      # expect(SomeWorker).not_to have_received(:perform_async)
      # expect(SomeWorker).to have_received(:perform_async)
      # expect(SomeWorker).to have_received(:perform_in)
      def_node_matcher :perform_method_expectation?, <<~PATTERN
        (send#{' '}
          (send nil? :expect $_)#{' '}
          {:not_to :to_not :to}#{' '}
          (send nil? :have_received (sym {:perform_async :perform_in}) ...))
      PATTERN

      # This pattern captures allow statements for perform_async and perform_in
      # allow(SomeWorker).to receive(:perform_async)
      # allow(SomeWorker).to receive(:perform_in)
      def_node_matcher :perform_method_allow?, <<~PATTERN
        (send
          (send nil? :allow $_)
          :to
          (send nil? :receive (sym {:perform_async :perform_in}) ...))
      PATTERN

      def on_send(node)
        check_expectation(node) || check_allow(node)
      end

      private

      def check_expectation(node)
        perform_method_expectation?(node) { return add_offense(node) }

        false
      end

      def check_allow(node)
        perform_method_allow?(node) { return add_offense(node) }

        false
      end
    end
  end
end
