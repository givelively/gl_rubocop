# frozen_string_literal: true

require 'rubocop'
require 'rubocop/rspec/support'
require 'gl_rubocop/gl_cops/prevent_erb_files'

RSpec.describe GLRubocop::GLCops::PreventErbFiles do
  include RuboCop::RSpec::ExpectOffense
  let(:config) { RuboCop::Config.new }
  let(:cop) { described_class.new(config) }
  let(:commissioner) { RuboCop::Cop::Commissioner.new([cop]) }
  let(:source) do
    Tempfile.open(['bad_file', '.erb']) do |file|
      file.write('bad contents')
      file.close
      file.path
    end
  end

  describe 'investigate' do
    it 'reports an offense if file name ends in .erb' do
      source_file = File.read(source)
      processed_source = RuboCop::ProcessedSource.new(source_file, RUBY_VERSION.to_f, source)
      investigation_report = commissioner.investigate(processed_source)
      expect(investigation_report.offenses.size).to eq(1)
    end
  end
end

