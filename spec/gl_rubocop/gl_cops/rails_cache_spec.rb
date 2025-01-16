# frozen_string_literal: true

require 'rubocop'
require 'rubocop/rspec/support'
require 'gl_rubocop/gl_cops/rails_cache'

RSpec.describe GLRubocop::GLCops::RailsCache do
  include RuboCop::RSpec::ExpectOffense

  subject(:cop) { described_class.new }

  it 'registers an offense when using Rails.cache.fetch' do
    expect_offense(<<~RUBY)
      Rails.cache.fetch('key') { 'value' }
      ^^^^^^^^^^^^^^^^^^^^^^^^ GLCops/RailsCache: Rails.cache should not be used directly
    RUBY
  end

  it 'registers an offense when using Rails.cache.read' do
    expect_offense(<<~RUBY)
      Rails.cache.read('key')
      ^^^^^^^^^^^^^^^^^^^^^^^ GLCops/RailsCache: Rails.cache should not be used directly
    RUBY
  end

  it 'registers an offense when using Rails.cache.write' do
    expect_offense(<<~RUBY)
      Rails.cache.write('key', 'value')
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ GLCops/RailsCache: Rails.cache should not be used directly
    RUBY
  end

  it 'registers an offense when using Rails.cache.delete' do
    expect_offense(<<~RUBY)
      Rails.cache.delete('key')
      ^^^^^^^^^^^^^^^^^^^^^^^^^ GLCops/RailsCache: Rails.cache should not be used directly
    RUBY
  end

  it 'registers an offense when using Rails.cache.exist?' do
    expect_offense(<<~RUBY)
      Rails.cache.exist?('key')
      ^^^^^^^^^^^^^^^^^^^^^^^^^ GLCops/RailsCache: Rails.cache should not be used directly
    RUBY
  end

  it 'registers an offense when using Rails.cache.clear' do
    expect_offense(<<~RUBY)
      Rails.cache.clear
      ^^^^^^^^^^^^^^^^^ GLCops/RailsCache: Rails.cache should not be used directly
    RUBY
  end

  it 'does not register an offense for other methods' do
    expect_no_offenses(<<~RUBY)
      SomeOtherClass.cache.fetch('key') { 'value' }
    RUBY
  end

  it 'registers an offense when using Rails.cache in a multi-line method chain' do
    expect_offense(<<~RUBY)
      Rails
      ^^^^^ GLCops/RailsCache: Rails.cache should not be used directly
        .cache
        .write('key', 'value')
    RUBY
  end
end
