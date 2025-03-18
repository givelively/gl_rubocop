module GLRubocop
  module GLCops
    class InteractorInheritsFromInteractorBase < RuboCop::Cop::Cop
      MSG = 'Interactor should inherit from InteractorBase'.freeze

      def on_class(klass)
        return unless klass.instance_of?(RuboCop::AST::ClassNode)
        return unless klass.parent_class.nil?

        add_offense(klass)
      end
    end
  end
end
