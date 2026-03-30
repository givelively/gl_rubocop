# frozen_string_literal: true

require 'rubocop'
require 'rubocop/rspec/support'
require 'gl_rubocop/gl_cops/require_i18n_in_component_previews'

RSpec.describe GLRubocop::GLCops::RequireI18nInComponentPreviews do
  subject(:cop) { described_class.new(config) }

  let(:config) { RuboCop::Config.new }
  let(:commissioner) { RuboCop::Cop::Commissioner.new([cop]) }
  let(:expected_message) do
    'GLCops/RequireI18nInComponentPreviews: Use i18n helpers (t() or I18n.t()) instead of naked strings in component previews.'
  end

  it 'registers an offense for a naked string as a keyword argument default' do
    source = <<~RUBY
      def initialize(text: 'Default Button')
        render(Core::Button::Component.new(text: text))
      end
    RUBY

    processed_source = parse_source(source)
    report = commissioner.investigate(processed_source)

    expect(report.offenses.size).to eq(1)
    expect(report.offenses.first.message).to eq(expected_message)
  end

  it 'registers an offense for a naked string passed as a component argument' do
    source = <<~RUBY
      def initialize(text: 'Default Button')
        render(Core::Button::Component.new(text: text))
      end
    RUBY

    processed_source = parse_source(source)
    report = commissioner.investigate(processed_source)

    expect(report.offenses.size).to eq(1)
    expect(report.offenses.first.message).to eq(expected_message)
  end

  it 'registers an offense for a naked string assigned to a variable' do
    source = <<~RUBY
      def initialize
        flash_value = 'Some message'
        render(Core::FlashMessage::Alert::Component.new(flash_value: flash_value))
      end
    RUBY

    processed_source = parse_source(source)
    report = commissioner.investigate(processed_source)

    expect(report.offenses.size).to eq(1)
    expect(report.offenses.first.message).to eq(expected_message)
  end

  it 'registers an offense for a naked string returned from a private method' do
    source = <<~RUBY
      private

      def long_message
        'Lorem ipsum dolor sit amet'
      end
    RUBY

    processed_source = parse_source(source)
    report = commissioner.investigate(processed_source)

    expect(report.offenses.size).to eq(1)
    expect(report.offenses.first.message).to eq(expected_message)
  end

  it 'does not register an offense for a template path string' do
    source = <<~RUBY
      def initialize
        render_with_template(template: 'core/alert/component_preview/default')
      end
    RUBY

    processed_source = parse_source(source)
    report = commissioner.investigate(processed_source)

    expect(report.offenses.size).to eq(0)
  end

  it 'does not register an offense when using t() helper' do
    source = <<~RUBY
      def initialize(text: t('components.button.default'))
        render(Core::Button::Component.new(text: text))
      end
    RUBY

    processed_source = parse_source(source)
    report = commissioner.investigate(processed_source)

    expect(report.offenses.size).to eq(0)
  end

  it 'does not register an offense when using I18n.t() helper' do
    source = <<~RUBY
      def initialize(text: I18n.t('components.button.default'))
        render(Core::Button::Component.new(text: text))
      end
    RUBY

    processed_source = parse_source(source)
    report = commissioner.investigate(processed_source)

    expect(report.offenses.size).to eq(0)
  end
end
