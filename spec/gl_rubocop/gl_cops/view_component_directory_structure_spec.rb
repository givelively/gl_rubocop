# frozen_string_literal: true

require 'spec_helper'
require 'rubocop/rspec/support'
require 'gl_rubocop/gl_cops/view_component_directory_structure'

RSpec.describe GLRubocop::GLCops::ViewComponentDirectoryStructure, :rubocop do
  include RuboCop::RSpec::ExpectOffense

  subject(:cop) { described_class.new(config) }

  let(:config) { RuboCop::Config.new }

  it 'does not register an offense for ApplicationViewComponent' do
    expect_no_offenses(<<~RUBY)
      class ApplicationViewComponent
      end
    RUBY
  end

  it 'does not register an offense when class belongs to an allowed base module' do
    expect_no_offenses(<<~RUBY)
      module Core
        module Users
          class Component < ApplicationViewComponent
          end
        end
      end
    RUBY
  end

  it 'registers an offense when class is under a disallowed base module' do
    offenses = inspect_source(<<~RUBY)
      module Billing
        module Users
          class Component < ApplicationViewComponent
          end
        end
      end
    RUBY

    expect(offenses.size).to eq(1)
    expect(offenses.first.message).to eq(
      'GLCops/ViewComponentDirectoryStructure: ViewComponent must belong to an allowed base module: Core, Admin, NonprofitAdmin, Packs, Users'
    )
  end
end
