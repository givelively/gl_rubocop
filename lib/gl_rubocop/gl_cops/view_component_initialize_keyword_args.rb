# rubocop:disable I18n/RailsI18n/DecorateString
module GLRubocop
  module GLCops
    # This cop ensures that ViewComponent initialize methods use keyword arguments only.
    #
    # Good:
    #   def initialize(name:, age:)
    #   def initialize(name:, age: 18)
    #   def initialize(**options)
    #
    # Bad:
    #   def initialize(name, age)
    #   def initialize(name, age:)
    class ViewComponentInitializeKeywordArgs < RuboCop::Cop::Cop
      MSG = 'ViewComponent initialize methods must use keyword arguments only.'

      def on_def(node)
        return unless node.method_name == :initialize
        return if node.arguments.empty?

        has_positional_args = node.arguments.any? do |arg|
          arg.arg_type? || arg.optarg_type? || arg.restarg_type?
        end

        add_offense(node, message: MSG) if has_positional_args
      end
    end
  end
end
# rubocop:enable I18n/RailsI18n/DecorateString
