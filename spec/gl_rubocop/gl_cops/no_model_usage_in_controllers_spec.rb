# frozen_string_literal: true

require 'rubocop'
require 'rubocop/rspec/support'
require 'gl_rubocop/gl_cops/no_model_usage_in_controllers'

RSpec.describe GLRubocop::GLCops::NoModelUsageInControllers do
  include RuboCop::RSpec::ExpectOffense

  subject(:cop) { described_class.new }

  before do
    allow(GLRubocop::Helpers::ActiveRecordModelRegistry).to receive(:for).and_return(
      Set.new(%w[Nonprofit Donation Webhook::Endpoint])
    )
  end

  define_method(:message) do |model|
    "GLCops/NoModelUsageInControllers: Do not use the `#{model}` model directly in a " \
      'controller. Move this logic into a GLCommand.'
  end

  context 'with class-level usage of a confirmed AR model' do
    it 'registers an offense for .find' do
      expect_offense(<<~RUBY)
        Nonprofit.find(params[:id])
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^ #{message('Nonprofit')}
      RUBY
    end

    it 'registers an offense for .find_by' do
      expect_offense(<<~RUBY)
        Nonprofit.find_by(email: params[:email])
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ #{message('Nonprofit')}
      RUBY
    end

    it 'registers an offense for .where' do
      expect_offense(<<~RUBY)
        Donation.where(nonprofit_id: params[:nonprofit_id])
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ #{message('Donation')}
      RUBY
    end

    it 'registers an offense for .create' do
      expect_offense(<<~RUBY)
        Donation.create(amount: params[:amount])
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ #{message('Donation')}
      RUBY
    end

    it 'registers an offense for .new' do
      expect_offense(<<~RUBY)
        Donation.new(amount: params[:amount])
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ #{message('Donation')}
      RUBY
    end

    it 'registers an offense for a namespaced model' do
      expect_offense(<<~RUBY)
        Webhook::Endpoint.find(params[:id])
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ #{message('Webhook::Endpoint')}
      RUBY
    end
  end

  context 'with instance-level usage of a variable assigned from a confirmed AR model' do
    it 'registers an offense for .save following Model.new' do
      expect_offense(<<~RUBY)
        def create
          donation = Donation.new(amount: params[:amount])
                     ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ #{message('Donation')}
          donation.save
          ^^^^^^^^^^^^^ #{message('Donation')}
        end
      RUBY
    end

    it 'registers an offense for .update! following Model.find' do
      expect_offense(<<~RUBY)
        def update
          nonprofit = Nonprofit.find(params[:id])
                      ^^^^^^^^^^^^^^^^^^^^^^^^^^^ #{message('Nonprofit')}
          nonprofit.update!(name: params[:name])
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ #{message('Nonprofit')}
        end
      RUBY
    end

    it 'does not carry variable tracking across separate method definitions' do
      expect_offense(<<~RUBY)
        def create
          donation = Donation.new(amount: params[:amount])
                     ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ #{message('Donation')}
        end

        def unrelated
          donation.save
        end
      RUBY
    end
  end

  context 'with constants that are not confirmed AR models' do
    it 'does not register an offense for .new on an unrelated class' do
      expect_no_offenses(<<~RUBY)
        NonprofitPolicy.new(current_user, nonprofit)
      RUBY
    end

    it 'does not register an offense for .find on an unrelated constant' do
      expect_no_offenses(<<~RUBY)
        Feature.find(:some_flag)
      RUBY
    end

    it 'does not register an offense for .save on a variable never assigned from a model' do
      expect_no_offenses(<<~RUBY)
        def create
          form = SomeForm.new(params)
          form.save
        end
      RUBY
    end

    it 'does not register an offense for an unrelated method on a confirmed model' do
      expect_no_offenses(<<~RUBY)
        Nonprofit.model_name
      RUBY
    end

    it 'does not confuse a namespaced constant with an unrelated model sharing its last segment' do
      expect_no_offenses(<<~RUBY)
        V2::Nonprofit.new(params)
      RUBY
    end
  end
end
