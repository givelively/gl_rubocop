# frozen_string_literal: true

require 'rubocop'
require 'rubocop/rspec/support'
require 'gl_rubocop/gl_cops/no_stubbing_perform_async'

RSpec.describe GLRubocop::GLCops::NoStubbingPerformAsync do
  subject(:cop) { described_class.new(config) }

  let(:config) { RuboCop::Config.new }
  let(:commissioner) { RuboCop::Cop::Commissioner.new([cop]) }
  let(:expected_message) do
    "GLCops/NoStubbingPerformAsync: Don't stub perform async. Use the rspec-sidekick matchers " \
      'instead: expect(JobClass).to have_enqueued_sidekiq_job'
  end

  it 'registers an offense when stubbing have_received' do
    source = <<~RUBY
      expect(SomeWorker).not_to have_received(:perform_async)
    RUBY

    processed_source = parse_source(source)
    report = commissioner.investigate(processed_source)

    expect(report.offenses.size).to eq(1)
    expect(report.offenses.first.message).to eq(expected_message)
  end

  it 'registers an offense when stubbing perform_in' do
    source = <<~RUBY
      expect(SomeWorker).not_to have_received(:perform_in)
    RUBY

    processed_source = parse_source(source)
    report = commissioner.investigate(processed_source)

    expect(report.offenses.size).to eq(1)
    expect(report.offenses.first.message).to eq(expected_message)
  end

  it 'registers an offense when using allow perform_in' do
    source = <<~RUBY
      allow(SomeWorker).to receive(:perform_in).with(12)
    RUBY

    processed_source = parse_source(source)
    report = commissioner.investigate(processed_source)

    expect(report.offenses.size).to eq(1)
    expect(report.offenses.first.message).to eq(expected_message)
  end

  it 'registers an offense when using expect and_return' do
    source = <<~RUBY
      expect(SomeWorker).to receive(:perform_async).and_return { 12 }
    RUBY

    processed_source = parse_source(source)
    report = commissioner.investigate(processed_source)

    expect(report.offenses.size).to eq(1)
    expect(report.offenses.first.message).to eq(expected_message)
  end
end
