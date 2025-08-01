# frozen_string_literal: true

require 'spec_helper'
require 'rubocop/rspec/support'
require 'gl_rubocop/gl_cops/unique_identifier'

RSpec.describe RuboCop::Cop::Layout::LineLength, :rubocop do
  include RuboCop::RSpec::ExpectOffense

  describe 'AllowedPatterns' do
    subject(:cop) { described_class.new(config) }

    let(:config) do
      RuboCop::Config.new(
        'Layout/LineLength' => {
          'Max' => 100,
          'AllowedPatterns' => [
            '^ *#',
            '^\s*[\'\"].*[\'\"]\s*$'
          ]
        }
      )
    end

    it 'does not register offense for long comment lines' do
      expect_no_offenses(<<~RUBY)
        #{'#' * 120}
      RUBY

      expect_no_offenses(<<~RUBY)
        ##{'a' * 120}
      RUBY
    end

    it 'does not register offense for long string literal lines' do
      expect_no_offenses(<<~RUBY)
        "#{'a' * 120}"
      RUBY
      expect_no_offenses(<<~RUBY)
        '#{'b' * 120}'
      RUBY
    end

    it 'registers offense for other long lines' do
      expect_offense(<<~RUBY)
        x = "#{'c' * 101}"
                                                                                                            ^^^^^^^ Line is too long. [107/100]
      RUBY
    end
  end
end
