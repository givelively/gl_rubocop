# frozen_string_literal: true

require 'rubocop'
require 'rubocop/rspec/support'
require 'gl_rubocop/gl_cops/no_hardcoded_strings_in_erb_text_elements'

RSpec.describe GLRubocop::GLCops::NoHardcodedStringsInErbTextElements do
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
    let(:erb_content) { '<p>Hello</p>' }

    it 'does not register an offense' do
      expect_no_offenses(<<~RUBY)
        render "component"
      RUBY
    end
  end

  context 'with a hardcoded string in a <p> element' do
    let(:erb_content) { '<p>Hello World</p>' }

    it 'registers an offense' do
      expect_offense(<<~RUBY)
        render "component"
        ^^^^^^^^^^^^^^^^^^ GLCops/NoHardcodedStringsInErbTextElements: Hardcoded string in <p> on line 1. Use an i18n expression (t()) or a variable.
      RUBY
    end
  end

  context 'with a hardcoded string in a <span> element' do
    let(:erb_content) { '<span>Click here</span>' }

    it 'registers an offense' do
      expect_offense(<<~RUBY)
        render "component"
        ^^^^^^^^^^^^^^^^^^ GLCops/NoHardcodedStringsInErbTextElements: Hardcoded string in <span> on line 1. Use an i18n expression (t()) or a variable.
      RUBY
    end
  end

  context 'with a hardcoded string in a heading element' do
    let(:erb_content) { '<h1>Page Title</h1>' }

    it 'registers an offense' do
      expect_offense(<<~RUBY)
        render "component"
        ^^^^^^^^^^^^^^^^^^ GLCops/NoHardcodedStringsInErbTextElements: Hardcoded string in <h1> on line 1. Use an i18n expression (t()) or a variable.
      RUBY
    end
  end

  context 'with a hardcoded string in a <button> element' do
    let(:erb_content) { '<button>Submit</button>' }

    it 'registers an offense' do
      expect_offense(<<~RUBY)
        render "component"
        ^^^^^^^^^^^^^^^^^^ GLCops/NoHardcodedStringsInErbTextElements: Hardcoded string in <button> on line 1. Use an i18n expression (t()) or a variable.
      RUBY
    end
  end

  context 'with a hardcoded string in a <label> element' do
    let(:erb_content) { '<label>Email address</label>' }

    it 'registers an offense' do
      expect_offense(<<~RUBY)
        render "component"
        ^^^^^^^^^^^^^^^^^^ GLCops/NoHardcodedStringsInErbTextElements: Hardcoded string in <label> on line 1. Use an i18n expression (t()) or a variable.
      RUBY
    end
  end

  context 'with an i18n expression in a <p> element' do
    let(:erb_content) { "<p><%= t('components.message') %></p>" }

    it 'does not register an offense' do
      expect_no_offenses(<<~RUBY)
        render "component"
      RUBY
    end
  end

  context 'with an i18n expression using I18n.t in a <span>' do
    let(:erb_content) { "<span><%= I18n.t('key') %></span>" }

    it 'does not register an offense' do
      expect_no_offenses(<<~RUBY)
        render "component"
      RUBY
    end
  end

  context 'with a variable reference in a <span>' do
    let(:erb_content) { '<span><%= @label_text %></span>' }

    it 'does not register an offense' do
      expect_no_offenses(<<~RUBY)
        render "component"
      RUBY
    end
  end

  context 'with an empty element' do
    let(:erb_content) { '<p></p>' }

    it 'does not register an offense' do
      expect_no_offenses(<<~RUBY)
        render "component"
      RUBY
    end
  end

  context 'with whitespace-only content' do
    let(:erb_content) { "<p>   \n   </p>" }

    it 'does not register an offense' do
      expect_no_offenses(<<~RUBY)
        render "component"
      RUBY
    end
  end

  context 'with nested elements (text inside a child tag)' do
    let(:erb_content) { '<p><span><%= t("key") %></span></p>' }

    it 'does not register an offense on the outer <p>' do
      expect_no_offenses(<<~RUBY)
        render "component"
      RUBY
    end
  end

  context 'with nested element containing a hardcoded string' do
    let(:erb_content) { '<p><span>Hello</span></p>' }

    it 'registers one offense on the inner <span>, not the outer <p>' do
      expect_offense(<<~RUBY)
        render "component"
        ^^^^^^^^^^^^^^^^^^ GLCops/NoHardcodedStringsInErbTextElements: Hardcoded string in <span> on line 1. Use an i18n expression (t()) or a variable.
      RUBY
    end
  end

  context 'with an element that has ERB attributes and a variable body' do
    let(:erb_content) { '<p class="<%= @variant %>"><%= @message_text %></p>' }

    it 'does not register an offense' do
      expect_no_offenses(<<~RUBY)
        render "component"
      RUBY
    end
  end

  context 'with a hardcoded string on a later line' do
    let(:erb_content) { <<~ERB }
      <div>
        <p>Some hardcoded text</p>
      </div>
    ERB

    it 'reports the correct line number in the offense message' do
      expect_offense(<<~RUBY)
        render "component"
        ^^^^^^^^^^^^^^^^^^ GLCops/NoHardcodedStringsInErbTextElements: Hardcoded string in <p> on line 2. Use an i18n expression (t()) or a variable.
      RUBY
    end
  end

  context 'with multiple hardcoded strings' do
    let(:erb_content) { '<p>First</p><span>Second</span>' }

    # RuboCop deduplicates offenses at the same source range, so only the first
    # offense (by tag iteration order) is reported. <span> precedes <p> in TEXT_TAGS.
    it 'registers an offense for the first matching element' do
      expect_offense(<<~RUBY)
        render "component"
        ^^^^^^^^^^^^^^^^^^ GLCops/NoHardcodedStringsInErbTextElements: Hardcoded string in <span> on line 1. Use an i18n expression (t()) or a variable.
      RUBY
    end
  end
end
