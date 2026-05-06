# frozen_string_literal: true

require 'spec_helper'
require 'rubocop/rspec/support'
require 'gl_rubocop/gl_cops/view_component_class_naming'

RSpec.describe GLRubocop::GLCops::ViewComponentClassNaming, :rubocop do
  include RuboCop::RSpec::ExpectOffense

  subject(:cop) { described_class.new(config) }

  let(:config) { RuboCop::Config.new }

  context 'when inheriting from ApplicationViewComponent' do
    it 'does not register an offense for Component' do
      expect_no_offenses(<<~RUBY)
        class Component < ApplicationViewComponent
        end
      RUBY
    end

    it 'does register an offense for any other class name' do
      expect_offense(<<~RUBY)
        class UserCardComponent < ApplicationViewComponent
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ GLCops/ViewComponentClassNaming: ViewComponent class names must be "Component".
        end
      RUBY
    end

    it 'does not register an offense for namespaced class names if the class name is Component' do
      expect_no_offenses(<<~RUBY)
        module UI
          class Component < ApplicationViewComponent
          end
        end
      RUBY
    end
  end

  context 'when inheriting from ApplicationViewComponentPreview' do
    it 'does not register an offense for ComponentPreview' do
      expect_no_offenses(<<~RUBY)
        class ComponentPreview < ApplicationViewComponentPreview
        end
      RUBY
    end

    it 'does register an offense for any other class name' do
      expect_offense(<<~RUBY)
        class UserCardComponentPreview < ApplicationViewComponentPreview
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ GLCops/ViewComponentClassNaming: ViewComponentPreview class names must be "ComponentPreview".
        end
      RUBY
    end

    it 'does not register an offense for namespaced class names if the class name is Component' do
      expect_no_offenses(<<~RUBY)
        module UI
          class ComponentPreview < ApplicationViewComponentPreview
          end
        end
      RUBY
    end
  end

  context 'when not inheriting from ApplicationViewComponent or ApplicationViewComponentPreview' do
    it 'does not register an offense' do
      expect_no_offenses(<<~RUBY)
        class UserCardComponent
        end
      RUBY
    end
  end
end
