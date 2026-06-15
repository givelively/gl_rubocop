# frozen_string_literal: true

require 'spec_helper'
require 'rubocop/rspec/support'
require 'gl_rubocop/gl_cops/view_component_inheritance'

RSpec.describe GLRubocop::GLCops::ViewComponentInheritance, :rubocop do
  include RuboCop::RSpec::ExpectOffense

  subject(:cop) { described_class.new(config) }

  let(:config) { RuboCop::Config.new }

  it 'does not register an offense for ApplicationViewComponent itself' do
    expect_no_offenses(<<~RUBY)
      class ApplicationViewComponent
      end
    RUBY
  end

  it 'does not register an offense for ApplicationViewComponentPreview itself' do
    expect_no_offenses(<<~RUBY)
      class ApplicationViewComponentPreview
      end
    RUBY
  end

  it 'does not register an offense when a component inherits from ApplicationViewComponent' do
    expect_no_offenses(<<~RUBY)
      class MyComponent < ApplicationViewComponent
      end
    RUBY
  end

  it 'registers an offense when a component inherits from another class' do
    expect_offense(<<~RUBY)
      class MyComponent < ViewComponent::Base
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ GLCops/ViewComponentInheritance: ViewComponents must inherit from ApplicationViewComponent
      end
    RUBY
  end

  it 'registers an offense when a component does not inherit from any class' do
    expect_offense(<<~RUBY)
      class MyComponent
      ^^^^^^^^^^^^^^^^^ GLCops/ViewComponentInheritance: ViewComponents must inherit from ApplicationViewComponent
      end
    RUBY
  end

  it 'does not register an offense when a preview inherits from ApplicationViewComponentPreview' do
    expect_no_offenses(<<~RUBY)
      class MyComponentPreview < ApplicationViewComponentPreview
      end
    RUBY
  end

  it 'registers an offense when a preview inherits from another class' do
    expect_offense(<<~RUBY)
      class MyComponentPreview < ViewComponent::Preview
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ GLCops/ViewComponentInheritance: ViewComponentPreviews must inherit from ApplicationViewComponentPreview
      end
    RUBY
  end

  it 'registers an offense when a preview does not inherit from any class' do
    expect_offense(<<~RUBY)
      class MyComponentPreview
      ^^^^^^^^^^^^^^^^^^^^^^^^ GLCops/ViewComponentInheritance: ViewComponentPreviews must inherit from ApplicationViewComponentPreview
      end
    RUBY
  end

  it 'does not register an offense for classes that are not components or previews' do
    expect_no_offenses(<<~RUBY)
      class SomeService < SomeBase
      end
    RUBY
  end
end
