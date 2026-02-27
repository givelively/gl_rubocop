# frozen_string_literal: true

require 'rubocop'
require 'rubocop/rspec/support'
require 'gl_rubocop/gl_cops/vcr_cassette_names'

RSpec.describe GLRubocop::GLCops::VcrCassetteNames do
  subject(:cop) { described_class.new(config) }

  let(:config) { RuboCop::Config.new }
  let(:commissioner) { RuboCop::Cop::Commissioner.new([cop]) }
  let(:expected_message) do
    'GLCops/VcrCassetteNames: VCR cassettes must have a name. ' \
      'Example: VCR.use_cassette("cassette_name") { ... }'
  end

  it 'registers an offense when VCR.use_cassette has no name' do
    source = <<~RUBY
      VCR.use_cassette do
        some_code
      end
    RUBY

    processed_source = parse_source(source)
    report = commissioner.investigate(processed_source)

    expect(report.offenses.size).to eq(1)
    expect(report.offenses.first.message).to eq(expected_message)
  end

  it 'registers an offense when VCR.use_cassette has empty arguments' do
    source = <<~RUBY
      VCR.use_cassette() do
        some_code
      end
    RUBY

    processed_source = parse_source(source)
    report = commissioner.investigate(processed_source)

    expect(report.offenses.size).to eq(1)
    expect(report.offenses.first.message).to eq(expected_message)
  end

  it 'does not register an offense when VCR.use_cassette has a string name' do
    source = <<~RUBY
      VCR.use_cassette('cassette_name') do
        some_code
      end
    RUBY

    processed_source = parse_source(source)
    report = commissioner.investigate(processed_source)

    expect(report.offenses.size).to eq(0)
  end

  it 'does not register an offense when VCR.use_cassette has a double-quoted string name' do
    source = <<~RUBY
      VCR.use_cassette("cassette_name") do
        some_code
      end
    RUBY

    processed_source = parse_source(source)
    report = commissioner.investigate(processed_source)

    expect(report.offenses.size).to eq(0)
  end

  it 'does not register an offense when VCR.use_cassette has an interpolated string name' do
    source = <<~RUBY
      VCR.use_cassette("cassette_\#{variable}") do
        some_code
      end
    RUBY

    processed_source = parse_source(source)
    report = commissioner.investigate(processed_source)

    expect(report.offenses.size).to eq(0)
  end

  it 'does not register an offense for other VCR methods' do
    source = <<~RUBY
      VCR.configure do |config|
        config.cassette_library_dir = 'spec/vcr'
      end
    RUBY

    processed_source = parse_source(source)
    report = commissioner.investigate(processed_source)

    expect(report.offenses.size).to eq(0)
  end
end
