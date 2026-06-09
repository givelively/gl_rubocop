# frozen_string_literal: true

require 'rubocop'
require 'rubocop/rspec/support'
require 'gl_rubocop/gl_cops/text_and_content_variable_naming'

RSpec.describe GLRubocop::GLCops::TextAndContentVariableNaming do
  include RuboCop::RSpec::ExpectOffense

  subject(:cop) { described_class.new(config) }

  let(:config) { RuboCop::Config.new }
  let(:file_path) { '/app/components/foo/component.html.erb' }
  let!(:processed_source) { parse_source('render "component"') }

  before do
    allow_any_instance_of(described_class).to receive(:processed_source)
      .and_return(processed_source)
    allow(processed_source).to receive(:file_path).and_return(file_path)
    allow(File).to receive(:read).with(file_path).and_return(erb_content)
  end

  context 'when in a non-ERB file' do
    let(:file_path) { '/app/components/foo/component.rb' }
    let(:erb_content) { '<p><%= @thing %></p>' }

    it 'does not register an offense' do
      expect_no_offenses(<<~RUBY)
        render "component"
      RUBY
    end
  end

  context 'with an instance variable lacking _text/_content suffix in a <p>' do
    let(:erb_content) { '<p><%= @message %></p>' }

    it 'registers an offense' do
      expect_offense(<<~RUBY)
        render "component"
        ^^^^^^^^^^^^^^^^^^ GLCops/TextAndContentVariableNaming: `message` is rendered inside a text element.Rename it with a `_text` suffix (plain text) or `_content` suffix (HTML content).
      RUBY
    end
  end

  context 'with an instance variable lacking _text/_content suffix in a <span>' do
    let(:erb_content) { '<span><%= @title %></span>' }

    it 'registers an offense' do
      expect_offense(<<~RUBY)
        render "component"
        ^^^^^^^^^^^^^^^^^^ GLCops/TextAndContentVariableNaming: `title` is rendered inside a text element.Rename it with a `_text` suffix (plain text) or `_content` suffix (HTML content).
      RUBY
    end
  end

  context 'with an instance variable ending with _text' do
    let(:erb_content) { '<p><%= @message_text %></p>' }

    it 'does not register an offense' do
      expect_no_offenses(<<~RUBY)
        render "component"
      RUBY
    end
  end

  context 'with an instance variable ending with _content' do
    let(:erb_content) { '<span><%= @banner_content %></span>' }

    it 'does not register an offense' do
      expect_no_offenses(<<~RUBY)
        render "component"
      RUBY
    end
  end

  context 'with a local variable named exactly `text`' do
    let(:erb_content) { '<p><%= text %></p>' }

    it 'does not register an offense' do
      expect_no_offenses(<<~RUBY)
        render "component"
      RUBY
    end
  end

  context 'with a local variable named exactly `content`' do
    let(:erb_content) { '<div><p><%= content %></p></div>' }

    it 'does not register an offense' do
      expect_no_offenses(<<~RUBY)
        render "component"
      RUBY
    end
  end

  context 'with an i18n call' do
    let(:erb_content) { "<p><%= t('key') %></p>" }

    it 'does not register an offense' do
      expect_no_offenses(<<~RUBY)
        render "component"
      RUBY
    end
  end

  context 'with a method call chain' do
    let(:erb_content) { '<p><%= @model.title %></p>' }

    it 'does not register an offense' do
      expect_no_offenses(<<~RUBY)
        render "component"
      RUBY
    end
  end

  context 'with a variable in an HTML attribute' do
    let(:erb_content) { '<p class="<%= @variant %>"><%= @label_text %></p>' }

    it 'does not register an offense for the attribute variable' do
      expect_no_offenses(<<~RUBY)
        render "component"
      RUBY
    end
  end

  context(
    'with a bare variable without suffix in an attribute and a properly named body variable'
  ) do
    let(:erb_content) do
      '<p class="tw:text-base tw:m-0 <%= concat_styles %>"><%= @thing_text %></p>'
    end

    it 'does not register an offense' do
      expect_no_offenses(<<~RUBY)
        render "component"
      RUBY
    end
  end

  context 'with an improperly named body variable alongside attribute ERB' do
    let(:erb_content) do
      '<p class="gl-font-base tw:m-0 <%= concat_styles %>"><%= @thing %></p>'
    end

    it 'registers an offense for @thing' do
      expect_offense(<<~RUBY)
        render "component"
        ^^^^^^^^^^^^^^^^^^ GLCops/TextAndContentVariableNaming: `thing` is rendered inside a text element.Rename it with a `_text` suffix (plain text) or `_content` suffix (HTML content).
      RUBY
    end
  end

  context 'with a local variable lacking suffix' do
    let(:erb_content) { '<span><%= label %></span>' }

    it 'registers an offense' do
      expect_offense(<<~RUBY)
        render "component"
        ^^^^^^^^^^^^^^^^^^ GLCops/TextAndContentVariableNaming: `label` is rendered inside a text element.Rename it with a `_text` suffix (plain text) or `_content` suffix (HTML content).
      RUBY
    end
  end

  context 'with multiple bad variables in different elements' do
    let(:erb_content) { '<h1><%= @title %></h1><p><%= @body %></p>' }

    # RuboCop deduplicates offenses at the same source range, so only the first
    # offense (by tag iteration order) is reported. <p> precedes <h1> in TEXT_TAGS.
    it 'registers an offense for the first matching element' do
      expect_offense(<<~RUBY)
        render "component"
        ^^^^^^^^^^^^^^^^^^ GLCops/TextAndContentVariableNaming: `body` is rendered inside a text element.Rename it with a `_text` suffix (plain text) or `_content` suffix (HTML content).
      RUBY
    end
  end

  context 'with a variable on a later line' do
    let(:erb_content) { <<~ERB }
      <div>
        <p><%= @thing %></p>
      </div>
    ERB

    it 'registers an offense' do
      expect_offense(<<~RUBY)
        render "component"
        ^^^^^^^^^^^^^^^^^^ GLCops/TextAndContentVariableNaming: `thing` is rendered inside a text element. Rename it with a `_text` suffix (plain text) or `_content` suffix (HTML content).
      RUBY
    end
  end
end
