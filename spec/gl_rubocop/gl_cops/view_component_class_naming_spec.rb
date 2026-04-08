# frozen_string_literal: true

require 'spec_helper'
require 'rubocop/rspec/support'
require 'gl_rubocop/gl_cops/view_component_class_naming'

RSpec.describe GLRubocop::GLCops::ViewComponentClassNaming, :rubocop do
  include RuboCop::RSpec::ExpectOffense

  subject(:cop) { described_class.new(config) }

  let(:config) { RuboCop::Config.new }

  it 'does not register an offense for Component' do
    expect_no_offenses(<<~RUBY)
      class Component
      end
    RUBY
  end

  it 'does not register an offense for ApplicationViewComponent' do
    expect_no_offenses(<<~RUBY)
      class ApplicationViewComponent
      end
    RUBY
  end

  it 'registers an offense for any other class name' do
    expect_offense(<<~RUBY)
      class UserComponent
      ^^^^^^^^^^^^^^^^^^^ GLCops/ViewComponentClassNaming: ViewComponent class names must be "Component".
      end
    RUBY
  end

  it 'registers an offense for namespaced class names' do
    expect_offense(<<~RUBY)
      class UI::Component
      ^^^^^^^^^^^^^^^^^^^ GLCops/ViewComponentClassNaming: ViewComponent class names must be "Component".
      end
    RUBY
  end
end
