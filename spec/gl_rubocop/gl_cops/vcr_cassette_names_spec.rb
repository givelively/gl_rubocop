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

  let(:expected_rspec_message) do
    'GLCops/VcrCassetteNames: VCR cassettes must have a name. ' \
      'Example: describe "test", vcr: { cassette_name: :my_cassette } do'
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

  context 'with RSpec metadata' do
    it 'registers an offense when using :vcr symbol without cassette_name' do
      source = <<~RUBY
        RSpec.describe DistributeData::FormatAndSendData, :vcr, type: :command do
          it 'does something' do
          end
        end
      RUBY

      processed_source = parse_source(source)
      report = commissioner.investigate(processed_source)

      expect(report.offenses.size).to eq(1)
      expect(report.offenses.first.message).to eq(expected_rspec_message)
    end

    it 'registers an offense when using vcr hash without cassette_name' do
      source = <<~RUBY
        describe 'something', vcr: { match_requests_on: %i[method uri] } do
          it 'does something' do
          end
        end
      RUBY

      processed_source = parse_source(source)
      report = commissioner.investigate(processed_source)

      expect(report.offenses.size).to eq(1)
      expect(report.offenses.first.message).to eq(expected_rspec_message)
    end

    it 'does not register an offense when vcr hash has cassette_name' do
      source = <<~RUBY
        describe '.create', vcr: { cassette_name: :chariot_connect_create } do
          it 'does something' do
          end
        end
      RUBY

      processed_source = parse_source(source)
      report = commissioner.investigate(processed_source)

      expect(report.offenses.size).to eq(0)
    end

    it 'does not register an offense when vcr hash has cassette_name with other options' do
      source = <<~RUBY
        context 'when the EIN exists', vcr: {
          match_requests_on: %i[method uri_for_stripe],
          cassette_name: :chariot_organization_search_found } do
          it 'does something' do
          end
        end
      RUBY

      processed_source = parse_source(source)
      report = commissioner.investigate(processed_source)

      expect(report.offenses.size).to eq(0)
    end

    it 'works with it/specify/example blocks' do
      source = <<~RUBY
        it 'does something', :vcr do
        end
      RUBY

      processed_source = parse_source(source)
      report = commissioner.investigate(processed_source)

      expect(report.offenses.size).to eq(1)
      expect(report.offenses.first.message).to eq(expected_rspec_message)
    end
  end
end
