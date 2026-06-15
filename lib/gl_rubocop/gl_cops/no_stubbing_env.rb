module GLRubocop
  module GLCops
    # This cop ensures that you don't stub ENV with `allow`/`expect` + `receive`.
    #
    # Stubbing ENV this way (even with `and_call_original`) only stubs the env vars the
    # spec explicitly knows about. Any var that is read but not stubbed - for example a
    # var that is present on CI but not locally, or vice versa - behaves inconsistently
    # and causes flaky failures.
    #
    # Instead, replace ENV wholesale with `stub_const`, building the hash from the real
    # ENV so unrelated vars keep working everywhere:
    #
    # Good:
    #   stub_const('ENV', ENV.to_hash.except('VAR_TO_UNSET').merge('VAR_TO_SET' => 'value'))
    #
    # Bad:
    #   allow(ENV).to receive(:[]).and_call_original
    #   allow(ENV).to receive(:[]).with('VAR_TO_SET').and_return('value')
    #   expect(ENV).to receive(:fetch)
    class NoStubbingEnv < RuboCop::Cop::Base
      MSG = "Don't stub ENV with allow/expect + receive. Use " \
            "stub_const('ENV', ENV.to_hash.except('VAR_TO_UNSET')." \
            "merge('VAR_TO_SET' => 'value')) instead, so unrelated ENV vars " \
            '(e.g. on CI) keep working.'.freeze

      # Match `allow(ENV).to receive(...)` / `expect(ENV).not_to receive(...)`, including
      # chained forms like `.and_call_original`, `.and_return(...)`, `.with(...)`.
      def_node_matcher :stubbing_env?, <<~PATTERN
        (send
          (send nil? {:allow :expect} (const {nil? cbase} :ENV))
          {:to :not_to :to_not}
          `(send nil? :receive ...))
      PATTERN

      def on_send(node)
        return unless stubbing_env?(node)

        add_offense(node)
      end
    end
  end
end
