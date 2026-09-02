# frozen_string_literal: true

require 'rubocop'
require 'rubocop/rspec/support'
require 'gl_rubocop/gl_cops/no_controllers_outside_packs'

RSpec.describe GLRubocop::GLCops::NoControllersOutsidePacks do
  include RuboCop::RSpec::ExpectOffense

  subject(:cop) { described_class.new }

  let(:message) do
    'GLCops/NoControllersOutsidePacks: New controllers must be placed within a pack ' \
      '(e.g. packs/my_pack/app/controllers), not app/controllers.'
  end

  it 'registers an offense for a controller defined outside app/controllers' do
    expect_offense(<<~RUBY, 'app/controllers/donations_controller.rb')
      class DonationsController < ApplicationController
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ #{message}
        def index
        end
      end
    RUBY
  end

  it 'registers an offense for a namespaced controller outside a pack' do
    expect_offense(<<~RUBY, 'app/controllers/nonprofit/donations_controller.rb')
      class Nonprofit::DonationsController < ApplicationController
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ #{message}
        def index
        end
      end
    RUBY
  end

  it 'registers an offense for a controller with no explicit superclass outside a pack' do
    expect_offense(<<~RUBY, 'app/controllers/donations_controller.rb')
      class DonationsController
      ^^^^^^^^^^^^^^^^^^^^^^^^^ #{message}
      end
    RUBY
  end

  it 'does not register an offense for a controller defined within a pack' do
    expect_no_offenses(<<~RUBY, 'packs/donations/app/controllers/donations_controller.rb')
      module Donations
        class DonationsController < ApplicationController
        end
      end
    RUBY
  end

  it 'does not register an offense for a nested pack path' do
    expect_no_offenses(<<~RUBY, 'packs/donations/app/public/controllers/donations_controller.rb')
      module Donations
        class DonationsController < ApplicationController
        end
      end
    RUBY
  end

  it 'does not register an offense for a non-controller class outside a pack' do
    expect_no_offenses(<<~RUBY, 'app/models/donation.rb')
      class Donation < ApplicationRecord
      end
    RUBY
  end

  it 'does not register an offense for a concern module outside a pack' do
    expect_no_offenses(<<~RUBY, 'app/controllers/concerns/donations_controller_concern.rb')
      module DonationsControllerConcern
        extend ActiveSupport::Concern
      end
    RUBY
  end
end
