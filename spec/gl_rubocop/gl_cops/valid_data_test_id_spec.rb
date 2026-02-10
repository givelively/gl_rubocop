# frozen_string_literal: true

require 'rubocop'
require 'rubocop/rspec/support'
require 'gl_rubocop/gl_cops/valid_data_test_id'

RSpec.describe GLRubocop::GLCops::ValidDataTestId do
  include RuboCop::RSpec::ExpectOffense

  subject(:cop) { described_class.new }

  let!(:processed_source) { parse_source(source) }
  let(:source) { 'render "component"' }

  before do
    allow_any_instance_of(described_class).to receive(:processed_source)
      .and_return(processed_source)
    allow(processed_source).to receive(:file_path).and_return(file_path)
    allow(File).to receive(:exist?).with(file_path).and_return(true)
    allow(File).to receive(:read).with(file_path).and_return(template_content)
  end

  context 'when in an ERB file' do
    let(:file_path) { '/path/to/component.html.erb' }

    context 'with valid data-test-id format' do
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

    context 'with invalid data-testid format' do
      let(:template_content) do
        <<~ERB
          <div data-testid="unique-id">Some content</div>
        ERB
      end

      it 'registers an offense' do
        expect_offense(<<~RUBY)
          render "component"
          ^^^^^^^^^^^^^^^^^^ GLCops/ValidDataTestId: Use data-test-id instead of data-testid
        RUBY
      end
    end

    context 'with invalid data-testId format (camelCase)' do
      let(:template_content) do
        <<~ERB
          <div data-testId="unique-id">Some content</div>
        ERB
      end

      it 'registers an offense' do
        expect_offense(<<~RUBY)
          render "component"
          ^^^^^^^^^^^^^^^^^^ GLCops/ValidDataTestId: Use data-test-id instead of data-testId
        RUBY
      end
    end

    context 'with invalid data_test_id format (snake_case)' do
      let(:template_content) do
        <<~ERB
          <div data_test_id="unique-id">Some content</div>
        ERB
      end

      it 'registers an offense' do
        expect_offense(<<~RUBY)
          render "component"
          ^^^^^^^^^^^^^^^^^^ GLCops/ValidDataTestId: Use data-test-id instead of data_test_id
        RUBY
      end
    end

    context 'with invalid dataTestId format (camelCase no dash)' do
      let(:template_content) do
        <<~ERB
          <div dataTestId="unique-id">Some content</div>
        ERB
      end

      it 'registers an offense' do
        expect_offense(<<~RUBY)
          render "component"
          ^^^^^^^^^^^^^^^^^^ GLCops/ValidDataTestId: Use data-test-id instead of dataTestId
        RUBY
      end
    end

    context 'with no test id attribute' do
      let(:template_content) do
        <<~ERB
          <div class="container">Some content</div>
        ERB
      end

      it 'does not register an offense' do
        expect_no_offenses(<<~RUBY)
          render "component"
        RUBY
      end
    end
  end

  context 'when in a HAML file' do
    let(:file_path) { '/path/to/component.html.haml' }

    context 'with valid data-test-id format' do
      let(:template_content) do
        <<~HAML
          %div{ "data-test-id": "unique-id" }
            Some content
        HAML
      end

      it 'does not register an offense' do
        expect_no_offenses(<<~RUBY)
          render "component"
        RUBY
      end
    end

    context 'with invalid data-testid format' do
      let(:template_content) do
        <<~HAML
          %div{ "data-testid": "unique-id" }
            Some content
        HAML
      end

      it 'registers an offense' do
        expect_offense(<<~RUBY)
          render "component"
          ^^^^^^^^^^^^^^^^^^ GLCops/ValidDataTestId: Use data-test-id instead of data-testid
        RUBY
      end
    end

    context 'with invalid data_test_id format in HAML hash' do
      let(:template_content) do
        <<~HAML
          %div{ data_test_id: "unique-id" }
            Some content
        HAML
      end

      it 'registers an offense' do
        expect_offense(<<~RUBY)
          render "component"
          ^^^^^^^^^^^^^^^^^^ GLCops/ValidDataTestId: Use data-test-id instead of data_test_id
        RUBY
      end
    end
  end

  context 'when checking string literals in Ruby code' do
    let(:file_path) { '/path/to/file.rb' }
    let(:template_content) { '' }

    it 'does not register an offense for valid data-test-id in string' do
      expect_no_offenses(<<~RUBY)
        html = '<div data-test-id="unique-id">Content</div>'
      RUBY
    end

    it 'registers an offense for invalid data-testid in string' do
      expect_offense(<<~RUBY)
        html = '<div data-testid="unique-id">Content</div>'
               ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ GLCops/ValidDataTestId: Use data-test-id instead of data-testid
      RUBY
    end
  end
end
