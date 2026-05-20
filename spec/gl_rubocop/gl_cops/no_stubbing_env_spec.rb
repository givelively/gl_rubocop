# frozen_string_literal: true

require 'rubocop'
require 'rubocop/rspec/support'
require 'gl_rubocop/gl_cops/no_stubbing_env'

RSpec.describe GLRubocop::GLCops::NoStubbingEnv do
  include RuboCop::RSpec::ExpectOffense

  subject(:cop) { described_class.new }

  let(:message) do
    "GLCops/NoStubbingEnv: Don't stub ENV with allow/expect + receive. Use " \
      "stub_const('ENV', ENV.to_hash.except('VAR_TO_UNSET').merge('VAR_TO_SET' => 'value')) " \
      'instead, so unrelated ENV vars (e.g. on CI) keep working.'
  end

  it 'registers an offense for allow(ENV).to receive(:[]).and_call_original' do
    expect_offense(<<~RUBY)
      allow(ENV).to receive(:[]).and_call_original
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ #{message}
    RUBY
  end

  it 'registers an offense for allow(ENV).to receive(:[]).with(...).and_return(...)' do
    expect_offense(<<~RUBY)
      allow(ENV).to receive(:[]).with('FOO').and_return('bar')
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ #{message}
    RUBY
  end

  it 'registers an offense for allow(ENV).to receive(:fetch)' do
    expect_offense(<<~RUBY)
      allow(ENV).to receive(:fetch)
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ #{message}
    RUBY
  end

  it 'registers an offense for expect(ENV).to receive(:[])' do
    expect_offense(<<~RUBY)
      expect(ENV).to receive(:[])
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^ #{message}
    RUBY
  end

  it 'registers an offense for expect(ENV).not_to receive(:[])' do
    expect_offense(<<~RUBY)
      expect(ENV).not_to receive(:[])
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ #{message}
    RUBY
  end

  it 'registers an offense for a top-level ::ENV constant' do
    expect_offense(<<~RUBY)
      allow(::ENV).to receive(:[]).and_call_original
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ #{message}
    RUBY
  end

  it 'does not register an offense for stub_const on ENV' do
    expect_no_offenses(<<~RUBY)
      stub_const('ENV', ENV.to_hash.except('VAR_TO_UNSET').merge('VAR_TO_SET' => 'value'))
    RUBY
  end

  it 'does not register an offense for plain expectations on ENV' do
    expect_no_offenses(<<~RUBY)
      expect(ENV['FOO']).to eq('bar')
    RUBY
  end

  it 'does not register an offense for stubbing another constant' do
    expect_no_offenses(<<~RUBY)
      allow(SomeClass).to receive(:[]).and_call_original
    RUBY
  end
end
