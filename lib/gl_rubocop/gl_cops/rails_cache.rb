module GLRubocop
  module GLCops
    class RailsCache < RuboCop::Cop::Base
    #  This cop ensures that Rails.cache is not directly used.
    #  This is to prevent generation of unique key ids (SIG Code Quality Discussion 2024-12-16):
    #  https://www.notion.so/givelively/2024-12-16-152eb3d1736e805abe85de1fd96f3599?pvs=4#15eeb3d1736e80ecb82defd5d6b1f0e5

      MSG = 'Rails.cache should not be used directly'.freeze

      def_node_matcher :using_rails_cache?, <<~PATTERN
        (send 
          (send (const nil? :Rails) :cache)
          {:fetch :read :write :delete :exist? :clear}
          ...)
      PATTERN

      def on_send(node)
        return unless using_rails_cache?(node)

        add_offense(node)
      end
    end
  end
end
