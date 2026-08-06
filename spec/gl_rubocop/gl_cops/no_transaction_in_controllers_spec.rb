# frozen_string_literal: true

require 'rubocop'
require 'rubocop/rspec/support'
require 'gl_rubocop/gl_cops/no_transaction_in_controllers'

RSpec.describe GLRubocop::GLCops::NoTransactionInControllers do
  include RuboCop::RSpec::ExpectOffense

  subject(:cop) { described_class.new }

  let(:message) do
    'GLCops/NoTransactionInControllers: Database transactions are not allowed in ' \
      'controllers. Move transactional logic into a GLCommand or service object.'
  end

  it 'registers an offense for ActiveRecord::Base.transaction with a block' do
    expect_offense(<<~RUBY)
      ActiveRecord::Base.transaction do
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ #{message}
        user.save!
      end
    RUBY
  end

  it 'registers an offense for ApplicationRecord.transaction' do
    expect_offense(<<~RUBY)
      ApplicationRecord.transaction do
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ #{message}
        user.save!
      end
    RUBY
  end

  it 'registers an offense for a model class transaction' do
    expect_offense(<<~RUBY)
      User.transaction do
      ^^^^^^^^^^^^^^^^ #{message}
        user.save!
      end
    RUBY
  end

  it 'registers an offense for transaction called with keyword arguments' do
    expect_offense(<<~RUBY)
      ActiveRecord::Base.transaction(requires_new: true) do
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ #{message}
        user.save!
      end
    RUBY
  end

  it 'does not register an offense for an unrelated transaction method on a variable' do
    expect_no_offenses(<<~RUBY)
      payment.transaction do
        charge
      end
    RUBY
  end

  it 'does not register an offense for an unrelated method on a constant' do
    expect_no_offenses(<<~RUBY)
      ActiveRecord::Base.connection
    RUBY
  end
end
