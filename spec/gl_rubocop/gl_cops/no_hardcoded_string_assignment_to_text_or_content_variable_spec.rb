# frozen_string_literal: true

require 'rubocop'
require 'rubocop/rspec/support'
require 'gl_rubocop/gl_cops/no_hardcoded_string_assignment_to_text_or_content_variable'

RSpec.describe GLRubocop::GLCops::NoHardcodedStringAssignmentToTextOrContentVariable do
  include RuboCop::RSpec::ExpectOffense

  subject(:cop) { described_class.new(config) }

  let(:config) { RuboCop::Config.new }

  # Local variable assignments
  describe 'local variable assignments (on_lvasgn)' do
    it 'registers an offense for a hardcoded string assigned to a _text variable' do
      expect_offense(<<~RUBY)
        title_text = 'Hello'
                     ^^^^^^^ GLCops/NoHardcodedStringAssignmentToTextOrContentVariable: `title_text` must not be assigned a hardcoded string. Create an i18n entry and use t() instead.
      RUBY
    end

    it 'registers an offense for a hardcoded string assigned to a _content variable' do
      expect_offense(<<~RUBY)
        banner_content = 'Some HTML'
                         ^^^^^^^^^^^ GLCops/NoHardcodedStringAssignmentToTextOrContentVariable: `banner_content` must not be assigned a hardcoded string. Create an i18n entry and use t() instead.
      RUBY
    end

    it 'registers an offense for a variable named exactly `text`' do
      expect_offense(<<~RUBY)
        text = 'Hello'
               ^^^^^^^ GLCops/NoHardcodedStringAssignmentToTextOrContentVariable: `text` must not be assigned a hardcoded string. Create an i18n entry and use t() instead.
      RUBY
    end

    it 'registers an offense for a variable named exactly `content`' do
      expect_offense(<<~RUBY)
        content = 'Some content'
                  ^^^^^^^^^^^^^^ GLCops/NoHardcodedStringAssignmentToTextOrContentVariable: `content` must not be assigned a hardcoded string. Create an i18n entry and use t() instead.
      RUBY
    end

    it 'does not register an offense when using t()' do
      expect_no_offenses(<<~RUBY)
        title_text = t('components.title')
      RUBY
    end

    it 'does not register an offense when using I18n.t()' do
      expect_no_offenses(<<~RUBY)
        title_text = I18n.t('components.title')
      RUBY
    end

    it 'does not register an offense when assigning a variable (not a string)' do
      expect_no_offenses(<<~RUBY)
        title_text = some_variable
      RUBY
    end

    it 'does not register an offense for config variables without the suffix' do
      expect_no_offenses(<<~RUBY)
        variant = 'primary'
        button_type = 'submit'
        href = '/some/path'
      RUBY
    end
  end

  # Instance variable assignments
  describe 'instance variable assignments (on_ivasgn)' do
    it 'registers an offense for a hardcoded string assigned to a _text ivar' do
      expect_offense(<<~RUBY)
        @label_text = 'Click here'
                      ^^^^^^^^^^^^ GLCops/NoHardcodedStringAssignmentToTextOrContentVariable: `@label_text` must not be assigned a hardcoded string. Create an i18n entry and use t() instead.
      RUBY
    end

    it 'registers an offense for a hardcoded string assigned to a _content ivar' do
      expect_offense(<<~RUBY)
        @body_content = '<p>HTML</p>'
                        ^^^^^^^^^^^^^ GLCops/NoHardcodedStringAssignmentToTextOrContentVariable: `@body_content` must not be assigned a hardcoded string. Create an i18n entry and use t() instead.
      RUBY
    end

    it 'does not register an offense when using t()' do
      expect_no_offenses(<<~RUBY)
        @label_text = t('components.label')
      RUBY
    end

    it 'does not register an offense for ivars without the suffix' do
      expect_no_offenses(<<~RUBY)
        @variant = 'primary'
      RUBY
    end
  end

  # Keyword argument defaults
  describe 'keyword argument defaults (on_kwoptarg)' do
    it 'registers an offense for a hardcoded string default on a _text param' do
      expect_offense(<<~RUBY)
        def initialize(button_text: 'Submit')
                                    ^^^^^^^^ GLCops/NoHardcodedStringAssignmentToTextOrContentVariable: `button_text` must not be assigned a hardcoded string. Create an i18n entry and use t() instead.
        end
      RUBY
    end

    it 'registers an offense for a hardcoded string default on a _content param' do
      expect_offense(<<~RUBY)
        def initialize(body_content: 'Default body')
                                     ^^^^^^^^^^^^^^ GLCops/NoHardcodedStringAssignmentToTextOrContentVariable: `body_content` must not be assigned a hardcoded string. Create an i18n entry and use t() instead.
        end
      RUBY
    end

    it 'registers an offense for a param named exactly `text`' do
      expect_offense(<<~RUBY)
        def initialize(text: 'Default')
                             ^^^^^^^^^ GLCops/NoHardcodedStringAssignmentToTextOrContentVariable: `text` must not be assigned a hardcoded string. Create an i18n entry and use t() instead.
        end
      RUBY
    end

    it 'does not register an offense when using t()' do
      expect_no_offenses(<<~RUBY)
        def initialize(button_text: t('components.button.default'))
        end
      RUBY
    end

    it 'does not register an offense for config keyword args with string defaults' do
      expect_no_offenses(<<~RUBY)
        def initialize(variant: 'primary', button_type: 'submit', href: '#')
        end
      RUBY
    end

    it 'does not register an offense for required keyword args (no default)' do
      expect_no_offenses(<<~RUBY)
        def initialize(button_text:)
        end
      RUBY
    end

    it 'does not register an offense for non-string defaults' do
      expect_no_offenses(<<~RUBY)
        def initialize(button_text: nil)
        end
      RUBY
    end
  end
end
