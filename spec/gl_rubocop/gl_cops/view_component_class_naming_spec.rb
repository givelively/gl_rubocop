# frozen_string_literal: true

require 'spec_helper'
require 'rubocop/rspec/support'
require 'gl_rubocop/gl_cops/view_component_class_naming'

RSpec.describe GLRubocop::GLCops::ViewComponentClassNaming, :rubocop do
  include RuboCop::RSpec::ExpectOffense

  subject(:cop) { described_class.new(config) }

  let(:config) { RuboCop::Config.new }

  it 'does not register an offense for Component inheriting from ViewComponent::Base' do
    expect_no_offenses(<<~RUBY)
      class Component < ViewComponent::Base
      end
    RUBY
  end

  it 'does not register an offense for ApplicationViewComponent inheriting from ViewComponent::Base' do
    expect_no_offenses(<<~RUBY)
      class ApplicationViewComponent < ViewComponent::Base
      end
    RUBY
  end

  it 'does not register an offense for classes not inheriting from ViewComponent::Base or ApplicationViewComponent' do
    expect_no_offenses(<<~RUBY)
      class UserComponent
      end
    RUBY
  end

  it 'registers an offense for any other class name inheriting from ViewComponent::Base' do
    expect_offense(<<~RUBY)
      class UserComponent < ViewComponent::Base
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ GLCops/ViewComponentClassNaming: ViewComponent class names must be "Component".
      end
    RUBY
  end

  it 'registers an offense for any other class name inheriting from ApplicationViewComponent' do
    expect_offense(<<~RUBY)
      class UserComponent < ApplicationViewComponent
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ GLCops/ViewComponentClassNaming: ViewComponent class names must be "Component".
      end
    RUBY
  end

  it 'registers an offense for namespaced class names inheriting from ViewComponent::Base' do
    expect_offense(<<~RUBY)
      class UI::Component < ViewComponent::Base
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ GLCops/ViewComponentClassNaming: ViewComponent class names must be "Component".
      end
    RUBY
  end
end
