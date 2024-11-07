# frozen_string_literal: true

require 'rubocop'
require 'rubocop/rspec/support'
require 'gl_rubocop/gl_cops/callback_method_names'

RSpec.describe GLRubocop::GLCops::CallbackMethodNames do
  subject(:cop) { described_class.new(config) }

  let(:config) { RuboCop::Config.new }
  let(:commissioner) { RuboCop::Cop::Commissioner.new([cop]) }
  let(:expected_message) do
    'GLCops/CallbackMethodNames: Use a named method for controller callbacks ' \
      'instead of an inline block.'
  end

  it 'registers an offense when using an inline block with a callback action' do
    source = <<~RUBY
      before_action do
        some_code
      end
    RUBY

    processed_source = parse_source(source)
    report = commissioner.investigate(processed_source)

    expect(report.offenses.size).to eq(1)
    expect(report.offenses.first.message).to eq(expected_message)
  end

  it 'does not register an event when using named methods with a callback action' do
    source = <<~RUBY
      around_action :validate_user
    RUBY

    processed_source = parse_source(source)
    report = commissioner.investigate(processed_source)

    expect(report.offenses.size).to eq(0)
  end
end
