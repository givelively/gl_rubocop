# frozen_string_literal: true

require 'gl_rubocop/helpers/pack_controller_registry'
require 'tmpdir'
require 'fileutils'

RSpec.describe GLRubocop::Helpers::PackControllerRegistry do
  let(:project_root) { Dir.mktmpdir }

  after { FileUtils.remove_entry(project_root) }

  define_method(:write_file) do |relative_path, content|
    path = File.join(project_root, relative_path)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, content)
  end

  define_method(:controller_packs) do
    described_class.for(project_root:, globs: described_class::DEFAULT_GLOBS)
  end

  before { described_class.reset_cache! }

  it 'maps a controller under app/controllers to its pack' do
    write_file('packs/tracking/app/controllers/events_controller.rb', <<~RUBY)
      module Tracking
        class EventsController
        end
      end
    RUBY

    expect(controller_packs).to eq('tracking/events' => 'tracking')
  end

  it 'maps a controller under app/public to its pack' do
    controller_path = 'packs/payment_gateway/app/public/payment_gateway/' \
                      'chariot_integrations_controller.rb'
    write_file(controller_path, <<~RUBY)
      module PaymentGateway
        class ChariotIntegrationsController
        end
      end
    RUBY

    expect(controller_packs).to eq('payment_gateway/chariot_integrations' => 'payment_gateway')
  end

  it 'maps a deeply namespaced controller' do
    write_file('packs/receipt_copy/app/controllers/receipts_controller.rb', <<~RUBY)
      module ReceiptCopy
        class ReceiptsController
        end
      end
    RUBY

    expect(controller_packs).to eq('receipt_copy/receipts' => 'receipt_copy')
  end

  it 'ignores non-controller classes' do
    write_file('packs/tracking/app/controllers/concerns/loggable.rb', <<~RUBY)
      module Tracking
        module Loggable
        end
      end
    RUBY

    expect(controller_packs).to eq({})
  end

  it 'ignores controllers outside of packs' do
    write_file('app/controllers/donations_controller.rb', <<~RUBY)
      class DonationsController
      end
    RUBY

    expect(controller_packs).to eq({})
  end

  it 'does not raise when a controller file has a syntax error' do
    write_file('packs/tracking/app/controllers/broken_controller.rb', 'class Broken < ')

    expect { controller_packs }.not_to raise_error
  end

  it 'memoizes results per project_root/globs pair' do
    write_file('packs/tracking/app/controllers/events_controller.rb', <<~RUBY)
      module Tracking
        class EventsController
        end
      end
    RUBY
    first_call = controller_packs

    write_file('packs/carts/app/controllers/carts_controller.rb', <<~RUBY)
      module Carts
        class CartsController
        end
      end
    RUBY
    second_call = described_class.for(project_root:, globs: described_class::DEFAULT_GLOBS)

    expect(first_call).to eq(second_call)
  end
end
