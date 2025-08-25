# frozen_string_literal: true

require 'spec_helper'
require 'rubocop/rspec/support'
require 'gl_rubocop/gl_cops/tailwind_no_contradicting_class_name'

RSpec.describe GLRubocop::GLCops::TailwindNoContradictingClassName do
  include RuboCop::RSpec::ExpectOffense

  subject(:cop) { described_class.new }

  context 'when using HAML templates' do
    let(:file_path) { '/path/to/component.html.haml' }
    let(:source) { 'render "component"' }
    let!(:processed_source) { parse_source(source) }

    before do
      allow_any_instance_of(described_class).to receive(:processed_source)
        .and_return(processed_source)
      allow(processed_source).to receive(:file_path).and_return(file_path)
      allow(File).to receive(:exist?).with(file_path).and_return(true)
      allow(File).to receive(:read).with(file_path).and_return(template_content)
    end

    context 'when the HAML template uses class shortcuts' do
      let(:template_content) do
        <<~HAML
          %div.tw:w-1.tw:w-2
        HAML
      end

      it 'registers an offense for invalid HAML class shortcuts with tw: prefix' do
        expect_offense(<<~RUBY)
          render "component"
          ^^^^^^^^^^^^^^^^^^ GLCops/TailwindNoContradictingClassName: Contradicting Tailwind CSS classes found: tw:w-1, tw:w-2 both affect the same CSS property
        RUBY
      end

      context 'when there are no contradicting classes' do
        let(:template_content) do
          <<~HAML
            %div.tw:w-1.tw:h-2
          HAML
        end

        it 'does not register an offense' do
          expect_no_offenses(<<~RUBY)
            render "component"
          RUBY
        end
      end

      context 'when there are no Tailwind classes' do
        let(:template_content) do
          <<~HAML
            %div{ class: 'container m-4 p-8' }
          HAML
        end

        it 'does not register an offense' do
          expect_no_offenses(<<~RUBY)
            render "component"
          RUBY
        end
      end
    end

    context 'when the HAML template uses hash syntax for class attribute' do
      let(:template_content) do
        <<~HAML
          %div{ class: 'tw:m-4 tw:m-8' }
        HAML
      end

      it 'registers an offense for contradicting classes in HAML with class attribute' do
        expect_offense(<<~RUBY)
          render "component"
          ^^^^^^^^^^^^^^^^^^ GLCops/TailwindNoContradictingClassName: Contradicting Tailwind CSS classes found: tw:m-4, tw:m-8 both affect the same CSS property
        RUBY
      end
    end
  end
end
