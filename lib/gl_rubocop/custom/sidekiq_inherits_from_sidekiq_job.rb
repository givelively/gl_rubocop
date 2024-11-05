module Custom
  class SidekiqInheritsFromSidekiqJob < RuboCop::Cop::Cop
    def on_class(klass)
      return unless klass.instance_of?(RuboCop::AST::ClassNode)
      return if klass.parent_class.present? || klass.identifier.short_name == :SidekiqJob

      add_offense(klass)
    end

    MSG = 'All Sidekiq workers and jobs should inherit from SidekiqJob'.freeze
  end
end
