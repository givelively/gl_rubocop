# frozen_string_literal: true

require 'rubocop'
require 'rubocop/rspec/support'
require 'gl_rubocop/gl_cops/consolidate_request_system_specs'

RSpec.describe GLRubocop::GLCops::ConsolidateRequestSystemSpecs do
  subject(:cop) { described_class.new(config) }

  let(:config) { RuboCop::Config.new }
  let(:commissioner) { RuboCop::Cop::Commissioner.new([cop]) }
  let(:expected_message) do
    'GLCops/ConsolidateRequestSystemSpecs: Consolidate examples with the same setup in ' \
      'request specs and system specs. Use a single it block instead of multiple it blocks.'
  end

  context 'when in request specs' do
    it 'registers an offense when describe block has multiple it blocks' do
      source = <<~RUBY
        RSpec.describe UsersController, type: :request do
          describe 'GET /users' do
            it 'returns success' do
              get users_path
            end

            it 'returns json' do
              get users_path
            end
          end
        end
      RUBY

      processed_source = parse_source(source, 'spec/requests/users_spec.rb')
      report = commissioner.investigate(processed_source)

      expect(report.offenses.size).to eq(1)
      expect(report.offenses.first.message).to eq(expected_message)
    end

    it 'registers an offense when context block has multiple it blocks' do
      source = <<~RUBY
        RSpec.describe UsersController, type: :request do
          context 'when logged in' do
            it 'returns success' do
              get users_path
            end

            it 'returns json' do
              get users_path
            end
          end
        end
      RUBY

      processed_source = parse_source(source, 'spec/requests/users_spec.rb')
      report = commissioner.investigate(processed_source)

      expect(report.offenses.size).to eq(1)
      expect(report.offenses.first.message).to eq(expected_message)
    end

    it 'registers multiple offenses when there are more than 2 it blocks' do
      source = <<~RUBY
        RSpec.describe UsersController, type: :request do
          describe 'GET /users' do
            it 'first test' do
            end

            it 'second test' do
            end

            it 'third test' do
            end
          end
        end
      RUBY

      processed_source = parse_source(source, 'spec/requests/users_spec.rb')
      report = commissioner.investigate(processed_source)

      expect(report.offenses.size).to eq(2)
    end

    it 'does not register an offense when there is only one it block' do
      source = <<~RUBY
        RSpec.describe UsersController, type: :request do
          describe 'GET /users' do
            it 'returns users' do
              get users_path
              expect(response).to be_successful
            end
          end
        end
      RUBY

      processed_source = parse_source(source, 'spec/requests/users_spec.rb')
      report = commissioner.investigate(processed_source)

      expect(report.offenses.size).to eq(0)
    end

    it 'works with specify and example blocks' do
      source = <<~RUBY
        RSpec.describe UsersController, type: :request do
          describe 'GET /users' do
            specify 'returns success' do
              get users_path
            end

            example 'returns json' do
              get users_path
            end
          end
        end
      RUBY

      processed_source = parse_source(source, 'spec/requests/users_spec.rb')
      report = commissioner.investigate(processed_source)

      expect(report.offenses.size).to eq(1)
    end
  end

  context 'when in system specs' do
    it 'registers an offense when describe block has multiple it blocks' do
      source = <<~RUBY
        RSpec.describe 'User login', type: :system do
          describe 'login flow' do
            it 'shows the login form' do
              visit login_path
            end

            it 'allows login' do
              visit login_path
              fill_in 'Email', with: 'user@example.com'
            end
          end
        end
      RUBY

      processed_source = parse_source(source, 'spec/system/login_spec.rb')
      report = commissioner.investigate(processed_source)

      expect(report.offenses.size).to eq(1)
      expect(report.offenses.first.message).to eq(expected_message)
    end

    it 'does not register an offense when there is only one it block' do
      source = <<~RUBY
        RSpec.describe 'User login', type: :system do
          describe 'login flow' do
            it 'logs in successfully' do
              visit login_path
              fill_in 'Email', with: 'user@example.com'
              click_button 'Login'
              expect(page).to have_content('Welcome')
            end
          end
        end
      RUBY

      processed_source = parse_source(source, 'spec/system/login_spec.rb')
      report = commissioner.investigate(processed_source)

      expect(report.offenses.size).to eq(0)
    end
  end

  context 'when in other spec types' do
    it 'does not register an offense for model specs with multiple it blocks' do
      source = <<~RUBY
        describe User do
          it 'validates presence of name' do
            user = User.new
            expect(user).not_to be_valid
          end

          it 'validates email format' do
            user = User.new(email: 'invalid')
            expect(user).not_to be_valid
          end
        end
      RUBY

      processed_source = parse_source(source, 'spec/models/user_spec.rb')
      report = commissioner.investigate(processed_source)

      expect(report.offenses.size).to eq(0)
    end

    it 'does not register an offense for service specs with multiple it blocks' do
      source = <<~RUBY
        describe UserService do
          it 'creates a user' do
            service.call
          end

          it 'sends an email' do
            service.call
          end
        end
      RUBY

      processed_source = parse_source(source, 'spec/services/user_service_spec.rb')
      report = commissioner.investigate(processed_source)

      expect(report.offenses.size).to eq(0)
    end
  end
end
