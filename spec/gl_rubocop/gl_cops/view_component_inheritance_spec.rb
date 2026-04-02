# frozen_string_literal: true

require 'spec_helper'
require 'rubocop/rspec/support'
require 'gl_rubocop/gl_cops/view_component_inheritance'

RSpec.describe GLRubocop::GLCops::ViewComponentInheritance, :rubocop do
	include RuboCop::RSpec::ExpectOffense

	subject(:cop) { described_class.new(config) }

	let(:config) { RuboCop::Config.new }

	it 'does not register an offense when inheriting from ApplicationViewComponent' do
		expect_no_offenses(<<~RUBY)
			class MyComponent < ApplicationViewComponent
			end
		RUBY
	end

	it 'does not register an offense when inheriting from ViewComponent::Base' do
		expect_no_offenses(<<~RUBY)
			class MyComponent < ViewComponent::Base
			end
		RUBY
	end

	it 'registers an offense when inheriting from another class' do
		expect_offense(<<~RUBY)
			class MyComponent < SomeOtherClass
			^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ GLCops/ViewComponentInheritance: ViewComponent must inherit from ApplicationViewComponent
			end
		RUBY
	end

	it 'registers an offense when not inheriting from any class' do
		expect_offense(<<~RUBY)
			class MyComponent
			^^^^^^^^^^^^^^^^^ GLCops/ViewComponentInheritance: ViewComponent must inherit from ApplicationViewComponent
			end
		RUBY
	end

	it 'registers an offense when inheriting from a namespaced class' do
		expect_offense(<<~RUBY)
			class MyComponent < Admin::BaseComponent
			^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ GLCops/ViewComponentInheritance: ViewComponent must inherit from ApplicationViewComponent
			end
		RUBY
	end
end
