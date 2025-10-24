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
      context 'when the class shortcuts contradict' do
        let(:template_content) do
          <<~HAML
            %div.tw:w-1.tw:w-2
          HAML
        end

        it 'registers an offense' do
          expect_offense(<<~RUBY)
            render "component"
            ^^^^^^^^^^^^^^^^^^ GLCops/TailwindNoContradictingClassName: Contradicting Tailwind CSS classes found: tw:w-1, tw:w-2 both affect the same CSS property
          RUBY
        end
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
      context 'when the classes contradict' do
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

      context 'when there are no contradicting classes' do
        let(:template_content) do
          <<~HAML
            %div{ class: 'tw:m-4 tw:p-8' }
          HAML
        end

        it 'does not register an offense' do
          expect_no_offenses(<<~RUBY)
            render "component"
          RUBY
        end
      end
    end

    context 'when the HAML template uses both class shortcuts and hash syntax' do
      context 'when the classes contradict' do
        let(:template_content) do
          <<~HAML
            %div.tw:m-4.{ class: 'tw:m-4' }
          HAML
        end

        it 'registers an offense' do
          expect_offense(<<~RUBY)
            render "component"
            ^^^^^^^^^^^^^^^^^^ GLCops/TailwindNoContradictingClassName: Contradicting Tailwind CSS classes found: tw:m-4, tw:m-4 both affect the same CSS property
          RUBY
        end
      end

      context 'when there are no contradicting classes' do
        let(:template_content) do
          <<~HAML
            %div.tw:m-4.{ class: 'tw:p-8' }
          HAML
        end

        it 'does not register an offense' do
          expect_no_offenses(<<~RUBY)
            render "component"
          RUBY
        end
      end
    end

    context 'when HAML template contains classes with breakpoints' do
      context 'when the classes contradict' do
        let(:template_content) do
          <<~HAML
            %div{ class: 'tw:md:m-4 tw:md:m-1' }
          HAML
        end

        it(
          'registers an offense'
        ) do
          expect_offense(<<~RUBY)
            render "component"
            ^^^^^^^^^^^^^^^^^^ GLCops/TailwindNoContradictingClassName: Contradicting Tailwind CSS classes found: tw:md:m-4, tw:md:m-1 both affect the same CSS property
          RUBY
        end
      end

      context 'when the classes do not contradict' do
        let(:template_content) do
          <<~HAML
            %div{ class: 'tw:inline-block tw:md:flex' }
          HAML
        end

        it 'does not register an offense' do
          expect_no_offenses(<<~RUBY)
            render "component"
          RUBY
        end
      end
    end
  end

  context 'when using string literals' do
    context 'when the classes contradict' do
      it 'registers an offense' do
        expect_offense(<<~RUBY)
          class_name = "tw:p-4 tw:p-6"
                       ^^^^^^^^^^^^^^^ GLCops/TailwindNoContradictingClassName: Contradicting Tailwind CSS classes found: tw:p-4, tw:p-6 both affect the same CSS property
        RUBY
      end
    end

    context 'when there are no contradicting classes' do
      it 'does not register an offense' do
        expect_no_offenses(<<~RUBY)
          class_name = "tw:p-4 tw:m-6"
        RUBY
      end
    end

    context 'when there are no Tailwind classes' do
      it 'does not register an offense' do
        expect_no_offenses(<<~RUBY)
          class_name = "container p-4 m-6"
        RUBY
      end
    end

    context 'when the string classes use breakpoints' do
      context 'when the classes contradict' do
        it 'registers an offense' do
          expect_offense(<<~RUBY)
            class_name = "tw:lg:h-10 tw:lg:h-20"
                         ^^^^^^^^^^^^^^^^^^^^^^^ GLCops/TailwindNoContradictingClassName: Contradicting Tailwind CSS classes found: tw:lg:h-10, tw:lg:h-20 both affect the same CSS property
          RUBY
        end
      end

      context 'when there are no contradicting classes' do
        it 'does not register an offense' do
          expect_no_offenses(<<~RUBY)
            class_name = "tw:h-10 tw:lg:h-20"
          RUBY
        end
      end
    end

    context 'when the string classes are constructed dynamically' do
      it 'does not register an offense' do
        expect_no_offenses(<<~RUBY)
          size = "4"
          class_name = "tw:m-\#{size} tw:m-6"
        RUBY
      end
    end

    context 'when the string classes are in single quotes' do
      context 'when the classes contradict' do
        it 'registers an offense' do
          expect_offense(<<~RUBY)
            class_name = 'tw:flex-row tw:flex-col'
                         ^^^^^^^^^^^^^^^^^^^^^^^^^ GLCops/TailwindNoContradictingClassName: Contradicting Tailwind CSS classes found: tw:flex-row, tw:flex-col both affect the same CSS property
          RUBY
        end
      end

      context 'when there are no contradicting classes' do
        it 'does not register an offense' do
          expect_no_offenses(<<~RUBY)
            class_name = 'tw:flex-row tw:block'
          RUBY
        end
      end
    end

    context 'when the string classes are values of a hash' do
      context 'when the classes contradict' do
        it 'registers an offense' do
          expect_offense(<<~RUBY)
            options = { class: "tw:pt-2 tw:pt-4" }
                               ^^^^^^^^^^^^^^^^^ GLCops/TailwindNoContradictingClassName: Contradicting Tailwind CSS classes found: tw:pt-2, tw:pt-4 both affect the same CSS property
          RUBY
        end
      end

      context 'when there are no contradicting classes' do
        it 'does not register an offense' do
          expect_no_offenses(<<~RUBY)
            options = { class: "tw:pt-2 tw:mb-4" }
          RUBY
        end
      end
    end
  end
end
