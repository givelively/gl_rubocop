# frozen_string_literal: true

require 'rubocop'
require 'rubocop/rspec/support'
require 'gl_rubocop/gl_cops/unique_identifier'

RSpec.describe GLRubocop::GLCops::UniqueIdentifier do
  include RuboCop::RSpec::ExpectOffense

  subject(:cop) { described_class.new(config) }

  let(:config) { RuboCop::Config.new }

  let!(:processed_source) { parse_source(source) }
  let(:source) { 'render "component"' }
  let(:file_path) { '/path/to/component.html.erb' }

  before do
    allow_any_instance_of(described_class).to receive(:processed_source)
      .and_return(processed_source)
    allow(processed_source).to receive(:file_path).and_return(file_path)
    allow(File).to receive(:exist?).with(file_path).and_return(true)
    allow(File).to receive(:read).with(file_path).and_return(template_content)
  end

  context 'when render method is used without data-test-id' do
    let(:template_content) do
      <<~ERB
        <div>Some content</div>
      ERB
    end

    it 'registers an offense' do
      expect_offense(<<~RUBY)
        render "component"
        ^^^^^^^^^^^^^^^^^^ GLCops/UniqueIdentifier: View components must include a data-test-id attribute
      RUBY
    end
  end

  context 'when render method is used with empty data-test-id' do
    let(:template_content) do
      <<~ERB
        <div data-test-id="">Some content</div>
      ERB
    end

    it 'registers an offense' do
      expect_offense(<<~RUBY)
        render "component", "data-test-id": ""
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ GLCops/UniqueIdentifier: data-test-id attribute must not be empty
      RUBY
    end
  end

  context 'when render method is used with non-empty data-test-id' do
    let(:template_content) do
      <<~ERB
        <div data-test-id="unique-id">Some content</div>
      ERB
    end

    it 'does not register an offense' do
      expect_no_offenses(<<~RUBY)
        render "component"
      RUBY
    end
  end

  context 'when in a preview file' do
    let(:file_path) { '/path/to/component_preview/default.html.erb' }
    let(:template_content) do
      <<~ERB
        <div>Some content</div>
      ERB
    end

    it 'does not register an offense' do
      expect_no_offenses(<<~RUBY)
        render "component"
      RUBY
    end
  end

  context 'when render method is used with invalid data-test-id formats' do
    invalid_templates = [
      '<div data-testId="unique-id">Some content</div>',
      '<div data-testid="unique-id">Some content</div>',
      '<div data-test_id="unique-id">Some content</div>'
    ]

    invalid_templates.each do |template|
      context "when template content is #{template}" do
        let(:template_content) { template }

        it 'registers an offense' do
          expect_offense(<<~RUBY)
            render "component"
            ^^^^^^^^^^^^^^^^^^ GLCops/UniqueIdentifier: View components must include a data-test-id attribute
          RUBY
        end
      end
    end
  end
end
