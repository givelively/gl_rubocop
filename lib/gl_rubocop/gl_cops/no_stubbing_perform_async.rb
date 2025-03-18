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
    #   expect(SomeWorker).not_to have_received(:perform_async)
    class NoStubbingPerformAsync < RuboCop::Cop::Cop
      MSG = "Don't stub perform async. Use the rspec-sidekick matchers instead: " \
        'expect(JobClass).to have_enqueued_sidekiq_job'.freeze
        
      # This pattern captures expectations like:
      # expect(SomeWorker).not_to have_received(:perform_async)
      # expect(SomeWorker).to have_received(:perform_async)
      def_node_matcher :perform_async_expectation?, <<~PATTERN
        (send 
          (send nil? :expect $_) 
          {:not_to :to_not :to} 
          (send nil? :have_received (sym :perform_async) ...))
      PATTERN
      
      # This pattern captures allow statements like:
      # allow(SomeWorker).to receive(:perform_async)
      def_node_matcher :perform_async_allow?, <<~PATTERN
        (send
          (send nil? :allow $_)
          :to
          (send nil? :receive (sym :perform_async) ...))
      PATTERN
      
      def on_send(node)
        check_expectation(node) || check_allow(node)
      end
      
      private
      
      def check_expectation(node)
        perform_async_expectation?(node) do |worker_class|
          add_offense(node) do |corrector|
            # Auto-correction isn't provided because it would require knowledge
            # of the better alternative specific to the test case
          end
          return true
        end
        false
      end
      
      def check_allow(node)
        perform_async_allow?(node) do |worker_class|
          add_offense(node) do |corrector|
            # Auto-correction isn't provided because it would require knowledge
            # of the better alternative specific to the test case
          end
          return true
        end
        false
      end
    end
  end
end
