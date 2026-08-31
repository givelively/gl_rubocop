module GLRubocop
  module GLCops
    # This cop bans new controllers from being defined outside of a pack.
    #
    # Per our controller standards RFC, all new controllers must live within a pack
    # (e.g. packs/my_pack/app/controllers) rather than the top-level app/controllers
    # directory, so related functionality stays grouped together as we migrate the
    # codebase to packs.
    #
    # The offense is determined by the file's own location (not just the `Include`
    # config), so this cop only flags controllers whose file path does not contain a
    # `packs/` segment. Existing controllers that predate this rule should be
    # grandfathered in via an `Exclude` list in the consuming project's RuboCop config,
    # so only newly added controllers are flagged.
    #
    # Good:
    #   # packs/donations/app/controllers/donations_controller.rb
    #   module Donations
    #     class DonationsController < ApplicationController
    #     end
    #   end
    #
    # Bad:
    #   # app/controllers/donations_controller.rb
    #   class DonationsController < ApplicationController
    #   end
    class NoControllersOutsidePacks < RuboCop::Cop::Base
      MSG = 'New controllers must be placed within a pack ' \
            '(e.g. packs/my_pack/app/controllers), not app/controllers.'.freeze

      PACK_PATH_SEGMENT = %r{(^|/)packs/}

      def on_class(node)
        return unless node.identifier.short_name.to_s.end_with?('Controller')
        return if within_pack?

        add_offense(node)
      end

      private

      def within_pack?
        PACK_PATH_SEGMENT.match?(processed_source.buffer.name.to_s)
      end
    end
  end
end
