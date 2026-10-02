# frozen_string_literal: true

require 'spec_helper'
require 'rubocop/rspec/support'
require 'gl_rubocop/gl_cops/sidekiq_inherits_from_sidekiq_job'

RSpec.describe GLRubocop::GLCops::SidekiqInheritsFromSidekiqJob, :rubocop do
  include RuboCop::RSpec::ExpectOffense

  subject(:cop) { described_class.new(config) }

  let(:config) { RuboCop::Config.new }

  it 'does not register an offense for SidekiqJob itself' do
    expect_no_offenses(<<~RUBY)
      class SidekiqJob
      end
    RUBY
  end

  it 'does not register an offense when a worker inherits from SidekiqJob' do
    expect_no_offenses(<<~RUBY)
      module Webhooks
        class ChargeWorker < SidekiqJob
        end
      end
    RUBY
  end

  it 'registers an offense when a worker does not inherit from any class' do
    expect_offense(<<~RUBY)
      class ChargeWorker
      ^^^^^^^^^^^^^^^^^^ GLCops/SidekiqInheritsFromSidekiqJob: All Sidekiq workers and jobs should inherit from SidekiqJob
      end
    RUBY
  end
end
