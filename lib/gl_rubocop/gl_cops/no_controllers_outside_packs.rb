module GLRubocop
  module GLCops
    # This cop bans new controllers from being defined outside of a pack.
    #
    # Per our controller standards RFC, all new controllers must live within a pack
    # (e.g. packs/my_pack/app/controllers) rather than the top-level app/controllers
    # directory, so related functionality stays grouped together as we migrate the
    # codebase to packs.
    #
    # This cop is scoped (via `Include`) to app/controllers, since controllers already
    # living within packs/**/app/controllers are never checked. Existing controllers
    # that predate this rule should be grandfathered in via an `Exclude` list in the
    # consuming project's RuboCop config, so only newly added controllers are flagged.
    #
    # Good:
    #   # packs/donations/app/controllers/donations_controller.rb
    #   class DonationsController < ApplicationController
    #   end
    #
    # Bad:
    #   # app/controllers/donations_controller.rb
    #   class DonationsController < ApplicationController
    #   end
    class NoControllersOutsidePacks < RuboCop::Cop::Base
      MSG = 'New controllers must be placed within a pack ' \
            '(e.g. packs/my_pack/app/controllers), not app/controllers.'.freeze

      def on_class(node)
        return unless node.identifier.short_name.to_s.end_with?('Controller')

        add_offense(node)
      end
    end
  end
end
