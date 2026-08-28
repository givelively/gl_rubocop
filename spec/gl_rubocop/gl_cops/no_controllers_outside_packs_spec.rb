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

  it 'registers an offense for a controller inheriting from ApplicationController' do
    expect_offense(<<~RUBY)
      class DonationsController < ApplicationController
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ #{message}
        def index
        end
      end
    RUBY
  end

  it 'registers an offense for a namespaced controller' do
    expect_offense(<<~RUBY)
      class Nonprofit::DonationsController < ApplicationController
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ #{message}
        def index
        end
      end
    RUBY
  end

  it 'registers an offense for a controller with no explicit superclass' do
    expect_offense(<<~RUBY)
      class DonationsController
      ^^^^^^^^^^^^^^^^^^^^^^^^^ #{message}
      end
    RUBY
  end

  it 'does not register an offense for a non-controller class' do
    expect_no_offenses(<<~RUBY)
      class Donation < ApplicationRecord
      end
    RUBY
  end

  it 'does not register an offense for a concern module' do
    expect_no_offenses(<<~RUBY)
      module DonationsControllerConcern
        extend ActiveSupport::Concern
      end
    RUBY
  end
end
