module GLRubocop
  module GLCops
    class InteractorInheritsFromInteractorBase < RuboCop::Cop::Cop
      def on_class(klass)
        return unless klass.instance_of?(RuboCop::AST::ClassNode)
        return unless klass.parent_class.nil?

        add_offense(klass)
      end

      MSG = 'Interactor should inherit from InteractorBase'.freeze
    end
  end
end
