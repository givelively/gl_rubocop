# frozen_string_literal: true

require 'rubocop'
require 'rubocop/rspec/support'
require 'gl_rubocop/gl_cops/view_component_initialize_keyword_args'

RSpec.describe GLRubocop::GLCops::ViewComponentInitializeKeywordArgs do
  subject(:cop) { described_class.new(config) }

  let(:config) { RuboCop::Config.new }
  let(:commissioner) { RuboCop::Cop::Commissioner.new([cop]) }
  let(:expected_message) do
    'GLCops/ViewComponentInitializeKeywordArgs: ViewComponent initialize methods must use keyword arguments only.'
  end

  it 'registers an offense when initialize has positional arguments' do
    source = <<~RUBY
      def initialize(name, age)
        @name = name
        @age = age
      end
    RUBY

    processed_source = parse_source(source)
    report = commissioner.investigate(processed_source)

    expect(report.offenses.size).to eq(1)
    expect(report.offenses.first.message).to eq(expected_message)
  end

  it 'registers an offense when initialize has mixed positional and keyword arguments' do
    source = <<~RUBY
      def initialize(name, age:)
        @name = name
        @age = age
      end
    RUBY

    processed_source = parse_source(source)
    report = commissioner.investigate(processed_source)

    expect(report.offenses.size).to eq(1)
    expect(report.offenses.first.message).to eq(expected_message)
  end

  it 'registers an offense when initialize has optional positional arguments' do
    source = <<~RUBY
      def initialize(name = "default")
        @name = name
      end
    RUBY

    processed_source = parse_source(source)
    report = commissioner.investigate(processed_source)

    expect(report.offenses.size).to eq(1)
    expect(report.offenses.first.message).to eq(expected_message)
  end

  it 'registers an offense when initialize has splat arguments' do
    source = <<~RUBY
      def initialize(*args)
        @args = args
      end
    RUBY

    processed_source = parse_source(source)
    report = commissioner.investigate(processed_source)

    expect(report.offenses.size).to eq(1)
    expect(report.offenses.first.message).to eq(expected_message)
  end

  it 'does not register an offense when initialize has only keyword arguments' do
    source = <<~RUBY
      def initialize(name:, age:)
        @name = name
        @age = age
      end
    RUBY

    processed_source = parse_source(source)
    report = commissioner.investigate(processed_source)

    expect(report.offenses.size).to eq(0)
  end

  it 'does not register an offense when initialize has keyword arguments with defaults' do
    source = <<~RUBY
      def initialize(name:, age: 18)
        @name = name
        @age = age
      end
    RUBY

    processed_source = parse_source(source)
    report = commissioner.investigate(processed_source)

    expect(report.offenses.size).to eq(0)
  end

  it 'does not register an offense when initialize has double splat arguments' do
    source = <<~RUBY
      def initialize(**options)
        @options = options
      end
    RUBY

    processed_source = parse_source(source)
    report = commissioner.investigate(processed_source)

    expect(report.offenses.size).to eq(0)
  end

  it 'does not register an offense when initialize has no arguments' do
    source = <<~RUBY
      def initialize
        @value = "default"
      end
    RUBY

    processed_source = parse_source(source)
    report = commissioner.investigate(processed_source)

    expect(report.offenses.size).to eq(0)
  end

  it 'does not register an offense for non-initialize methods' do
    source = <<~RUBY
      def some_method(name, age)
        @name = name
        @age = age
      end
    RUBY

    processed_source = parse_source(source)
    report = commissioner.investigate(processed_source)

    expect(report.offenses.size).to eq(0)
  end
end
