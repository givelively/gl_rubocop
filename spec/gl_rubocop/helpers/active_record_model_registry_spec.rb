# frozen_string_literal: true

require 'gl_rubocop/helpers/active_record_model_registry'
require 'tmpdir'
require 'fileutils'

RSpec.describe GLRubocop::Helpers::ActiveRecordModelRegistry do
  let(:project_root) { Dir.mktmpdir }

  after { FileUtils.remove_entry(project_root) }

  define_method(:write_model) do |relative_path, content|
    path = File.join(project_root, relative_path)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, content)
  end

  define_method(:model_names) do
    described_class.for(project_root:, globs: ['app/models/**/*.rb'])
  end

  before { described_class.reset_cache! }

  it 'includes a class that directly inherits from ApplicationRecord' do
    write_model('app/models/nonprofit.rb', 'class Nonprofit < ApplicationRecord; end')

    expect(model_names).to include('Nonprofit')
  end

  it 'includes a class that directly inherits from ActiveRecord::Base' do
    write_model('app/models/address_join.rb', 'class AddressJoin < ActiveRecord::Base; end')

    expect(model_names).to include('AddressJoin')
  end

  it 'includes a class that transitively inherits from ApplicationRecord' do
    write_model('app/models/campaign.rb', 'class Campaign < ApplicationRecord; end')
    write_model('app/models/fundraiser.rb', 'class Fundraiser < Campaign; end')

    expect(model_names).to include('Campaign', 'Fundraiser')
  end

  it 'resolves namespaced classes that inherit from a class in an enclosing namespace' do
    write_model('app/models/datawarehouse/base_record.rb', <<~RUBY)
      module Datawarehouse
        class BaseRecord < ApplicationRecord; end
      end
    RUBY
    write_model('app/models/datawarehouse/line_item.rb', <<~RUBY)
      module Datawarehouse
        class LineItem < BaseRecord; end
      end
    RUBY

    expect(model_names).to include('Datawarehouse::BaseRecord', 'Datawarehouse::LineItem')
  end

  it 'excludes plain Ruby objects with no AR ancestor' do
    write_model('app/models/array_stringifier.rb', 'class ArrayStringifier; end')

    expect(model_names).not_to include('ArrayStringifier')
  end

  it 'excludes classes that inherit from an unrelated superclass' do
    write_model('app/models/too_many_retries.rb', 'class TooManyRetries < StandardError; end')

    expect(model_names).not_to include('TooManyRetries')
  end

  it 'does not raise when a model file has a syntax error' do
    write_model('app/models/broken.rb', 'class Broken < ApplicationRecord')

    expect { model_names }.not_to raise_error
  end

  it 'does not infinite-loop on an inheritance cycle' do
    write_model('app/models/circular.rb', <<~RUBY)
      class A < B; end
      class B < A; end
    RUBY

    expect { model_names }.not_to raise_error
    expect(model_names).not_to include('A', 'B')
  end

  it 'memoizes results per project_root/globs pair' do
    write_model('app/models/nonprofit.rb', 'class Nonprofit < ApplicationRecord; end')
    first_call = model_names

    write_model('app/models/donation.rb', 'class Donation < ApplicationRecord; end')
    second_call = described_class.for(project_root:, globs: ['app/models/**/*.rb'])

    expect(first_call).to eq(second_call)
  end
end
