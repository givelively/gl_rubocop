# frozen_string_literal: true

require 'rubocop'
require 'rubocop/rspec/support'
require 'gl_rubocop/gl_cops/no_routes_outside_packs'

RSpec.describe GLRubocop::GLCops::NoRoutesOutsidePacks do
  include RuboCop::RSpec::ExpectOffense

  subject(:cop) { described_class.new }

  before do
    allow(GLRubocop::Helpers::PackControllerRegistry).to receive(:for).and_return(
      'tracking/events' => 'tracking',
      'receipt_copy/receipts' => 'receipt_copy',
      'nonprofit_admin/registrations' => 'nonprofit_admin',
      'payment_gateway/chariot_integrations' => 'payment_gateway',
      'carts/checkouts' => 'carts'
    )
  end

  define_method(:message) do |controller, pack|
    "GLCops/NoRoutesOutsidePacks: Routes for the `#{controller}` controller must be " \
      "defined in packs/#{pack}/public/config/routes.rb (packs/#{pack}), not here."
  end

  context 'when the route is defined outside of the owning pack' do
    it 'registers an offense for a `resources` call with an implicit controller' do
      expect_offense(<<~RUBY, 'config/routes.rb')
        namespace :tracking do
          resources :events, only: :create
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ #{message('tracking/events', 'tracking')}
        end
      RUBY
    end

    it 'registers an offense for a `resources` call with an explicit `controller:` option' do
      expect_offense(<<~RUBY, 'config/routes/nonprofit_admin_routes.rb')
        scope '/nonprofits/:nonprofit_slug', as: 'nonprofit' do
          resources :receipts,
          ^^^^^^^^^^^^^^^^^^^^ #{message('receipt_copy/receipts', 'receipt_copy')}
                    controller: 'receipt_copy/receipts',
                    param: :line_item_id,
                    only: %i[show create]
        end
      RUBY
    end

    it 'registers an offense for a `resource` call, pluralizing the controller name' do
      expect_offense(<<~RUBY, 'config/routes.rb')
        namespace :payment_gateway do
          resource :chariot_integration, only: %i[create destroy]
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ #{message('payment_gateway/chariot_integrations', 'payment_gateway')}
        end
      RUBY
    end

    it 'registers an offense for a `get` call with an explicit `to:` option, combining namespace' do
      expect_offense(<<~RUBY, 'config/routes.rb')
        namespace :nonprofit_admin do
          get '/apply/for-membership', to: 'registrations#new'
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ #{message('nonprofit_admin/registrations', 'nonprofit_admin')}
        end
      RUBY
    end

    it 'registers an offense for a `resources` call with a symbol `controller:` option' do
      expect_offense(<<~RUBY, 'config/routes.rb')
        namespace :tracking do
          resources :things, controller: :events
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ #{message('tracking/events', 'tracking')}
        end
      RUBY
    end

    it 'registers an offense for a `scope` call with a symbol `module:` option' do
      expect_offense(<<~RUBY, 'config/routes.rb')
        scope module: :tracking do
          resources :events, only: :create
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ #{message('tracking/events', 'tracking')}
        end
      RUBY
    end

    it 'registers an offense for a `resource` call whose name is already plural' do
      expect_offense(<<~RUBY, 'config/routes.rb')
        namespace :carts do
          resource :checkouts, only: %i[create]
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ #{message('carts/checkouts', 'carts')}
        end
      RUBY
    end
  end

  context 'when the route is defined within the owning pack routes file' do
    it 'does not register an offense' do
      expect_no_offenses(<<~RUBY, 'packs/tracking/public/config/routes.rb')
        namespace :tracking do
          resources :events, only: :create
        end
      RUBY
    end
  end

  context 'when the controller path is not a pack-based controller' do
    it 'does not register an offense' do
      expect_no_offenses(<<~RUBY, 'config/routes.rb')
        get 'nonprofits/oauth', to: 'nonprofits_oauth#new'
        resources :customers, defaults: { format: 'json' }
      RUBY
    end
  end

  context 'when a controller path is grandfathered' do
    subject(:cop) { described_class.new(config) }

    let(:config) do
      RuboCop::Config.new(
        { 'GLCops/NoRoutesOutsidePacks' => { 'Grandfathered' => ['receipt_copy/receipts'] } }
      )
    end

    it 'does not register an offense' do
      expect_no_offenses(<<~RUBY, 'config/routes/nonprofit_admin_routes.rb')
        resources :receipts, controller: 'receipt_copy/receipts', only: %i[show create]
      RUBY
    end
  end
end
