# frozen_string_literal: true

require 'rubocop'
require 'rubocop/rspec/support'
require 'gl_rubocop/gl_cops/rails_cache'

RSpec.describe GLRubocop::GLCops::LimitFlashOptions, :rubocop do
  include RuboCop::RSpec::ExpectOffense

  subject(:cop) { described_class.new }

  context 'when checking flash hash assignment' do
    it 'registers an offense for disallowed flash key' do
      expect_offense(<<~RUBY)
        flash[:error] = "Not allowed"
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ GLCops/LimitFlashOptions: This cop checks for the use of flash options not in the allowlist. Please limit flash options to those defined in the application configuration.
      RUBY
    end

    it 'does not register an offense for allowed flash key' do
      expect_no_offenses(<<~RUBY)
        flash[:success] = "Allowed"
      RUBY
    end
  end

  context 'when checking flash.now hash assignment' do
    it 'registers an offense for disallowed flash.now key' do
      expect_offense(<<~RUBY)
        flash.now[:error] = "Not allowed"
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ GLCops/LimitFlashOptions: This cop checks for the use of flash options not in the allowlist. Please limit flash options to those defined in the application configuration.
      RUBY
    end

    it 'does not register an offense for allowed flash.now key' do
      expect_no_offenses(<<~RUBY)
        flash.now[:info] = "Allowed"
      RUBY
    end
  end

  context 'when checking Alert::Component.new' do
    it 'registers an offense for disallowed type' do
      expect_offense(<<~RUBY)
        Alert::Component.new(type: :error, message: "msg")
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ GLCops/LimitFlashOptions: This cop checks for the use of flash options not in the allowlist. Please limit flash options to those defined in the application configuration.
      RUBY
    end

    it 'does not register an offense for allowed type' do
      expect_no_offenses(<<~RUBY)
        Alert::Component.new(type: :success, message: "msg")
      RUBY
    end
  end

  context 'when checking Notifications::Dismissible::Component.new' do
    it 'registers an offense for disallowed variant' do
      expect_offense(<<~RUBY)
        Notifications::Dismissible::Component.new(variant: :error, message: "msg")
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ GLCops/LimitFlashOptions: This cop checks for the use of flash options not in the allowlist. Please limit flash options to those defined in the application configuration.
      RUBY
    end

    it 'does not register an offense for allowed variant' do
      expect_no_offenses(<<~RUBY)
        Notifications::Dismissible::Component.new(variant: :warning, message: "msg")
      RUBY
    end
  end
end
