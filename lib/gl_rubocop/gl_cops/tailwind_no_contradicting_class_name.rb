# frozen_string_literal: true

require_relative '../helpers/haml_content_helper'

module GLRubocop
  module GLCops
    # Cop to detect contradicting Tailwind CSS class names
    #
    # @example
    #   # bad
    #   %div{ class: "tw:w-1 tw:w-2" }
    #   .tw:h-5.tw:h-6
    #   %button.tw:w-1.tw:w-2
    #
    #
    #   # good
    #   %div{ class: "tw:w-1 tw:h-2" }
    #   tw:h-5
    #   %button.tw:m-4.tw:p-8

    class TailwindNoContradictingClassName < RuboCop::Cop::Cop
      include GLRubocop::HamlContentHelper
      MSG =
        'Contradicting Tailwind CSS classes found: %<classes>s both affect the same CSS property'
      GIVELIVELY_TAILWIND_CLASS_PREFIX = 'tw:'

      # Tailwind CSS property groups that should not contradict
      PROPERTY_GROUPS = {
        # Width
        'w' => %w[w],
        # Height
        'h' => %w[h],
        # Margin
        'm' => %w[m mt mr mb ml mx my],
        'mt' => %w[m mt my],
        'mr' => %w[m mr mx],
        'mb' => %w[m mb my],
        'ml' => %w[m ml mx],
        'mx' => %w[m mx mr ml],
        'my' => %w[m my mt mb],
        # Padding
        'p' => %w[p pt pr pb pl px py],
        'pt' => %w[p pt py],
        'pr' => %w[p pr px],
        'pb' => %w[p pb py],
        'pl' => %w[p pl px],
        'px' => %w[p px pr pl],
        'py' => %w[p py pt pb],
        # Display
        'block' => %w[block hidden flex inline inline-block inline-flex grid inline-grid table],
        'hidden' => %w[block hidden flex inline inline-block inline-flex grid inline-grid table],
        'flex' => %w[block hidden flex inline inline-block inline-flex grid inline-grid table],
        'inline' => %w[block hidden flex inline inline-block inline-flex grid inline-grid table],
        'inline-block' => %w[block hidden flex inline inline-block inline-flex grid inline-grid
                             table],
        'inline-flex' => %w[block hidden flex inline inline-block inline-flex grid inline-grid
                            table],
        'grid' => %w[block hidden flex inline inline-block inline-flex grid inline-grid table],
        'inline-grid' => %w[block hidden flex inline inline-block inline-flex grid inline-grid
                            table],
        'table' => %w[block hidden flex inline inline-block inline-flex grid inline-grid table],
        # Position
        'absolute' => %w[static relative absolute fixed sticky],
        'relative' => %w[static relative absolute fixed sticky],
        'fixed' => %w[static relative absolute fixed sticky],
        'static' => %w[static relative absolute fixed sticky],
        'sticky' => %w[static relative absolute fixed sticky],
        # Text alignment
        'text-left' => %w[text-left text-center text-right text-justify],
        'text-center' => %w[text-left text-center text-right text-justify],
        'text-right' => %w[text-left text-center text-right text-justify],
        'text-justify' => %w[text-left text-center text-right text-justify],
        # Flex direction
        'flex-row' => %w[flex-row flex-row-reverse flex-col flex-col-reverse],
        'flex-row-reverse' => %w[flex-row flex-row-reverse flex-col flex-col-reverse],
        'flex-col' => %w[flex-row flex-row-reverse flex-col flex-col-reverse],
        'flex-col-reverse' => %w[flex-row flex-row-reverse flex-col flex-col-reverse],
        # Justify content
        'justify-start' => %w[justify-start justify-end justify-center justify-between
                              justify-around justify-evenly],
        'justify-end' => %w[justify-start justify-end justify-center justify-between justify-around
                            justify-evenly],
        'justify-center' => %w[justify-start justify-end justify-center justify-between
                               justify-around justify-evenly],
        'justify-between' => %w[justify-start justify-end justify-center justify-between
                                justify-around justify-evenly],
        'justify-around' => %w[justify-start justify-end justify-center justify-between
                               justify-around justify-evenly],
        'justify-evenly' => %w[justify-start justify-end justify-center justify-between
                               justify-around justify-evenly]
      }.freeze

      def on_send(node)
        return unless render_method?(node)
        return unless haml_file?

        haml_content = read_haml_file
        return unless haml_content

        check_haml_content(haml_content, node)
      end

      private

      def render_method?(node)
        node.method_name == :render && node.arguments.any?
      end

      def check_haml_content(content, node)
        classes = extract_all_classes(content)
        contradicting_classes = find_contradicting_classes(classes)

        return if contradicting_classes.empty?

        contradicting_classes.each do |group|
          add_offense(
            node,
            message: format(MSG, classes: group.join(', '))
          )
        end
      end

      def extract_all_classes(content)
        classes = []

        # Extract from HAML class shortcuts (e.g., %div.tw:w-1.tw:w-2)
        content.scan(/^[^#]*%\w+(?:\.[^{\s#]+)+/) do |match|
          class_shortcuts = match.scan(/\.([^.{\s#]+)/).flatten
          classes.concat(class_shortcuts)
        end

        # Extract from HAML hash syntax (e.g., %div{ class: 'tw:m-4 tw:m-8' })
        content.scan(/class:\s*['"]([^'"]+)['"]/) do |match|
          class_list = match[0].split(/\s+/)
          classes.concat(class_list)
        end

        classes.select { |cls| tailwind_class?(cls) }
      end

      def tailwind_class?(class_name)
        class_name.start_with?(GIVELIVELY_TAILWIND_CLASS_PREFIX)
      end

      # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      def find_contradicting_classes(classes)
        # Remove the 'tw:' prefix for property matching
        normalized_classes = classes.map { |cls| cls.sub(matcher, '') }

        contradictions = []

        normalized_classes.each_with_index do |first_class, index|
          first_property = extract_css_property(first_class)
          next unless valid_property?(first_property)

          classes_to_compare = normalized_classes[(index + 1)..]

          classes_to_compare.each_with_index do |second_class, j|
            second_property = extract_css_property(second_class)
            next unless valid_property?(second_property)

            next unless properties_contradict?(first_property, second_property)

            original_class1 = classes[index]
            original_class2 = classes[index + j + 1]
            contradictions << [original_class1, original_class2]
          end
        end

        contradictions
      end
      # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

      def matcher
        /^#{GIVELIVELY_TAILWIND_CLASS_PREFIX}/o
      end

      def valid_property?(property)
        property && PROPERTY_GROUPS[property]
      end

      def extract_css_property(class_name)
        # Handle cases like 'w-1', 'mt-4', 'text-left', etc.
        case class_name
        when /^(w|h)-/
          ::Regexp.last_match(1)
        when /^(m[trblxy]?)-/
          ::Regexp.last_match(1)
        when /^(p[trblxy]?)-/
          ::Regexp.last_match(1)
        when /^(block|hidden|flex|inline|inline-block|inline-flex|grid|inline-grid|table)$/
          ::Regexp.last_match(1)
        when /^(static|relative|absolute|fixed|sticky)$/
          ::Regexp.last_match(1)
        when /^(text-(?:left|center|right|justify))$/
          ::Regexp.last_match(1)
        when /^(flex-(?:row|row-reverse|col|col-reverse))$/
          ::Regexp.last_match(1)
        when /^(justify-(?:start|end|center|between|around|evenly))$/
          ::Regexp.last_match(1)
        end
      end

      def properties_contradict?(first_prop, second_prop)
        first_prop_group = PROPERTY_GROUPS[first_prop]
        second_prop_group = PROPERTY_GROUPS[second_prop]

        return false unless first_prop_group && second_prop_group

        # Check if both properties belong to the same contradicting group
        first_prop_group.intersect?(second_prop_group)
      end
    end
  end
end
