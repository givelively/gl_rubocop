module GLRubocop
  module GLCops
    class SidekiqInheritsFromSidekiqJob < RuboCop::Cop::Cop
      MSG = 'All Sidekiq workers and jobs should inherit from SidekiqJob'.freeze

      def on_class(klass)
        return unless klass.instance_of?(RuboCop::AST::ClassNode)
        return if klass.parent_class.present? || klass.identifier.short_name == :SidekiqJob

        add_offense(klass)
      end
    end
  end
end
