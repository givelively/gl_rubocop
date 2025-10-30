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
            %div{ class: 'tw:mt-4 tw:m-8' }
          HAML
        end

        it 'registers an offense for contradicting classes in HAML with class attribute' do
          expect_offense(<<~RUBY)
            render "component"
            ^^^^^^^^^^^^^^^^^^ GLCops/TailwindNoContradictingClassName: Contradicting Tailwind CSS classes found: tw:mt-4, tw:m-8 both affect the same CSS property
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

    context 'when HAML template contains classes with simple breakpoints' do
      context 'when the classes contradict' do
        context 'when the breakpoints are the same' do
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

    context 'when the HAML template contains classes with breakpoint ranges' do
      context 'when the breakpoints use upper and lower bound ranges' do
        context 'when the breakpoints overlap' do
          let(:template_content) do
            <<~HAML
              %div{ class: 'tw:md:w-4 tw:lg:max-xl:w-8' }
            HAML
          end

          it(
            'registers an offense'
          ) do
            expect_offense(<<~RUBY)
              render "component"
              ^^^^^^^^^^^^^^^^^^ GLCops/TailwindNoContradictingClassName: Contradicting Tailwind CSS classes found: tw:md:w-4, tw:lg:max-xl:w-8 both affect the same CSS property
            RUBY
          end
        end

        context 'when the breakpoints do not overlap' do
          let(:template_content) do
            <<~HAML
              %div{ class: 'tw:sm:max-md:h-10 tw:lg:max-xl:h-20' }
            HAML
          end

          it 'does not register an offense' do
            expect_no_offenses(<<~RUBY)
              render "component"
            RUBY
          end
        end
      end

      context 'when the breakpoints use upper bounds' do
        context 'when the breakpoints overlap' do
          let(:template_content) do
            <<~HAML
              %div{ class: 'tw:max-md:mt-4 tw:max-sm:mt-1' }
            HAML
          end

          it(
            'registers an offense'
          ) do
            expect_offense(<<~RUBY)
              render "component"
              ^^^^^^^^^^^^^^^^^^ GLCops/TailwindNoContradictingClassName: Contradicting Tailwind CSS classes found: tw:max-md:mt-4, tw:max-sm:mt-1 both affect the same CSS property
            RUBY
          end
        end

        context 'when the breakpoints do not overlap' do
          let(:template_content) do
            <<~HAML
              %div{ class: 'tw:max-sm:pt-2 tw:md:max-lg:pt-4' }
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

    context 'when the HAML template has multiple lines' do
      context 'when the classes contradict' do
        let(:template_content) do
          <<~HAML
            %div.container
              %h1 Title
              %div.content
                %p.tw:m-4.tw:m-8 Some content here.
          HAML
        end

        it 'registers an offense' do
          expect_offense(<<~RUBY)
            render "component"
            ^^^^^^^^^^^^^^^^^^ GLCops/TailwindNoContradictingClassName: Contradicting Tailwind CSS classes found: tw:m-4, tw:m-8 both affect the same CSS property
          RUBY
        end
      end
    end

    context 'when the HAML template contains classes with arbitrary values' do
      context 'when the classes contradict' do
        let(:template_content) do
          <<~HAML
            %div{ class: 'tw:mt-[10px] tw:mt-[20px]' }
          HAML
        end

        it(
          'registers an offense'
        ) do
          expect_offense(<<~RUBY)
            render "component"
            ^^^^^^^^^^^^^^^^^^ GLCops/TailwindNoContradictingClassName: Contradicting Tailwind CSS classes found: tw:mt-[10px], tw:mt-[20px] both affect the same CSS property
          RUBY
        end
      end

      context 'when there are no contradicting classes' do
        let(:template_content) do
          <<~HAML
            %div{ class: 'tw:mt-[10px] tw:mb-4' }
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

  context 'when using ERB templates' do
    let(:file_path) { '/path/to/component.html.erb' }
    let(:source) { 'render "component"' }
    let!(:processed_source) { parse_source(source) }

    before do
      allow_any_instance_of(described_class).to receive(:processed_source)
        .and_return(processed_source)
      allow(processed_source).to receive(:file_path).and_return(file_path)
      allow(File).to receive(:exist?).with(file_path).and_return(true)
      allow(File).to receive(:read).with(file_path).and_return(template_content)
    end

    context 'when the ERB template uses class attributes' do
      context 'when the classes contradict' do
        let(:template_content) do
          <<~ERB
            <div class="tw:text-center tw:text-left"></div>
          ERB
        end

        it 'registers an offense' do
          expect_offense(<<~RUBY)
            render "component"
            ^^^^^^^^^^^^^^^^^^ GLCops/TailwindNoContradictingClassName: Contradicting Tailwind CSS classes found: tw:text-center, tw:text-left both affect the same CSS property
          RUBY
        end
      end

      context 'when there are no contradicting classes' do
        let(:template_content) do
          <<~ERB
            <div class="tw:text-center tw:m-4"></div>
          ERB
        end

        it 'does not register an offense' do
          expect_no_offenses(<<~RUBY)
            render "component"
          RUBY
        end
      end

      context 'when the ERB template has multiple lines' do
        context 'when the classes contradict' do
          let(:template_content) do
            <<~ERB
              <div class="container">
                <h1>Title</h1>
                <div class="content">
                  <p class="tw:p-4 tw:p-8">Some content here.</p>
                </div>
              </div>
            ERB
          end

          it 'registers an offense' do
            expect_offense(<<~RUBY)
              render "component"
              ^^^^^^^^^^^^^^^^^^ GLCops/TailwindNoContradictingClassName: Contradicting Tailwind CSS classes found: tw:p-4, tw:p-8 both affect the same CSS property
            RUBY
          end
        end
      end

      context 'when the ERB template contains classes with simple breakpoint' do
        context 'when the classes contradict' do
          let(:template_content) do
            <<~ERB
              <div class="tw:sm:w-4 tw:sm:w-8"></div>
            ERB
          end

          it(
            'registers an offense'
          ) do
            expect_offense(<<~RUBY)
              render "component"
              ^^^^^^^^^^^^^^^^^^ GLCops/TailwindNoContradictingClassName: Contradicting Tailwind CSS classes found: tw:sm:w-4, tw:sm:w-8 both affect the same CSS property
            RUBY
          end
        end

        context 'when there are no contradicting classes' do
          let(:template_content) do
            <<~ERB
              <div class="tw:sm:w-4 tw:md:h-8"></div>
            ERB
          end

          it 'does not register an offense' do
            expect_no_offenses(<<~RUBY)
              render "component"
            RUBY
          end
        end
      end
    end

    context 'when the ERB template uses class attributes in rails hashes' do
      context 'when the classes contradict' do
        let(:template_content) do
          <<~ERB
            <%= radio_button_tag 'option', 'value', { class: 'tw:pt-2 tw:pt-4' } %>
          ERB
        end

        it 'registers an offense' do
          expect_offense(<<~RUBY)
            render "component"
            ^^^^^^^^^^^^^^^^^^ GLCops/TailwindNoContradictingClassName: Contradicting Tailwind CSS classes found: tw:pt-2, tw:pt-4 both affect the same CSS property
          RUBY
        end
      end

      context 'when there are no contradicting classes' do
        let(:template_content) do
          <<~ERB
            <%= radio_button_tag 'option', 'value', { class: 'tw:pt-2 tw:mb-4' } %>
          ERB
        end

        it 'does not register an offense' do
          expect_no_offenses(<<~RUBY)
            render "component"
          RUBY
        end
      end
    end

    context 'when the ERB template uses class attributes in rails symbol hashes' do
      context 'when the classes contradict' do
        let(:template_content) do
          <<~ERB
            <%= text_field_tag 'field_name', 'value', :class => 'tw:font-thin tw:font-extrabold' %>
          ERB
        end

        it 'registers an offense' do
          expect_offense(<<~RUBY)
            render "component"
            ^^^^^^^^^^^^^^^^^^ GLCops/TailwindNoContradictingClassName: Contradicting Tailwind CSS classes found: tw:font-thin, tw:font-extrabold both affect the same CSS property
          RUBY
        end
      end

      context 'when there are no contradicting classes' do
        let(:template_content) do
          <<~ERB
            <%= text_field_tag 'field_name', 'value', :class => 'tw:font-extrabold tw:text-base' %>
          ERB
        end

        it 'does not register an offense' do
          expect_no_offenses(<<~RUBY)
            render "component"
          RUBY
        end
      end
    end

    context 'when the ERB template uses content tag with class attributes' do
      context 'when the classes contradict' do
        let(:template_content) do
          <<~ERB
            <%= content_tag :div, 'Hello', class: 'tw:overflow-auto tw:overflow-visible' %>
          ERB
        end

        it 'registers an offense' do
          expect_offense(<<~RUBY)
            render "component"
            ^^^^^^^^^^^^^^^^^^ GLCops/TailwindNoContradictingClassName: Contradicting Tailwind CSS classes found: tw:overflow-auto, tw:overflow-visible both affect the same CSS property
          RUBY
        end
      end

      context 'when there are no contradicting classes' do
        let(:template_content) do
          <<~ERB
            <%= content_tag :div, 'Hello', class: 'tw:overflow-auto tw:text-center' %>
          ERB
        end

        it 'does not register an offense' do
          expect_no_offenses(<<~RUBY)
            render "component"
          RUBY
        end
      end
    end

    context 'when the ERB template uses class attributes in rails helpers' do
      context 'when the classes contradict' do
        let(:template_content) do
          <<~ERB
            <%= link_to 'Click here', '#', class: 'tw:min-w-8 tw:min-w-16' %>
          ERB
        end

        it 'registers an offense' do
          expect_offense(<<~RUBY)
            render "component"
            ^^^^^^^^^^^^^^^^^^ GLCops/TailwindNoContradictingClassName: Contradicting Tailwind CSS classes found: tw:min-w-8, tw:min-w-16 both affect the same CSS property
          RUBY
        end
      end

      context 'when there are no contradicting classes' do
        let(:template_content) do
          <<~ERB
            <%= link_to 'Click here', '#', class: 'tw:rounded-b-lg tw:rounded-t-md' %>
          ERB
        end

        it 'does not register an offense' do
          expect_no_offenses(<<~RUBY)
            render "component"
          RUBY
        end
      end
    end

    context 'when the ERB template contains classes with simple breakpoints' do
      context 'when the classes contradict' do
        let(:template_content) do
          <<~ERB
            <div class="tw:lg:h-10 tw:lg:h-20"></div>
          ERB
        end

        it(
          'registers an offense'
        ) do
          expect_offense(<<~RUBY)
            render "component"
            ^^^^^^^^^^^^^^^^^^ GLCops/TailwindNoContradictingClassName: Contradicting Tailwind CSS classes found: tw:lg:h-10, tw:lg:h-20 both affect the same CSS property
          RUBY
        end
      end

      context 'when there are no contradicting classes' do
        let(:template_content) do
          <<~ERB
            <div class="tw:h-10 tw:lg:h-20"></div>
          ERB
        end

        it 'does not register an offense' do
          expect_no_offenses(<<~RUBY)
            render "component"
          RUBY
        end
      end
    end

    context 'when the ERB template contains classes with breakpoint ranges' do
      context 'when the breakpoints use upper and lower bound ranges' do
        context 'when the breakpoints overlap' do
          let(:template_content) do
            <<~ERB
              <div class="tw:md:h-10 tw:lg:max-xl:h-20"></div>
            ERB
          end

          it(
            'registers an offense'
          ) do
            expect_offense(<<~RUBY)
              render "component"
              ^^^^^^^^^^^^^^^^^^ GLCops/TailwindNoContradictingClassName: Contradicting Tailwind CSS classes found: tw:md:h-10, tw:lg:max-xl:h-20 both affect the same CSS property
            RUBY
          end
        end

        context 'when the breakpoints do not overlap' do
          let(:template_content) do
            <<~ERB
              <div class="tw:sm:max-md:h-10 tw:lg:max-xl:h-20"></div>
            ERB
          end

          it 'does not register an offense' do
            expect_no_offenses(<<~RUBY)
              render "component"
            RUBY
          end
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

    context 'when the string classes contain simple breakpoints' do
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

    context 'when the string classes contain breakpoint ranges' do
      context 'when the breakpoints use upper and lower bound ranges' do
        context 'when the breakpoints overlap' do
          it 'registers an offense' do
            expect_offense(<<~RUBY)
              class_name = "tw:md:h-10 tw:lg:max-xl:h-20"
                           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ GLCops/TailwindNoContradictingClassName: Contradicting Tailwind CSS classes found: tw:md:h-10, tw:lg:max-xl:h-20 both affect the same CSS property
            RUBY
          end
        end

        context 'when the breakpoints do not overlap' do
          it 'does not register an offense' do
            expect_no_offenses(<<~RUBY)
              class_name = "tw:sm:max-md:h-10 tw:lg:max-xl:h-20"
            RUBY
          end
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
