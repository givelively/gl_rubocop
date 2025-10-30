# frozen_string_literal: true

require_relative '../helpers/haml_content_helper'
require_relative '../helpers/erb_content_helper'

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

    # rubocop:disable Metrics/ClassLength
    class TailwindNoContradictingClassName < RuboCop::Cop::Cop
      include GLRubocop::HamlContentHelper
      include GLRubocop::ErbContentHelper

      MSG =
        'Contradicting Tailwind CSS classes found: %<classes>s both affect the same CSS property'
      GIVELIVELY_TAILWIND_CLASS_PREFIX = 'tw:'

      # Tailwind CSS property groups that should not contradict
      CONTRADICTION_GROUPS = {
        width: %w[w],
        height: %w[h],
        max_width: %w[max-w],
        max_height: %w[max-h],
        min_width: %w[min-w],
        min_height: %w[min-h],
        margin_top: %w[m my mt],
        margin_right: %w[m mx mr],
        margin_bottom: %w[m my mb],
        margin_left: %w[m mx ml],
        padding_top: %w[p py pt],
        padding_right: %w[p px pr],
        padding_bottom: %w[p py pb],
        padding_left: %w[p px pl],
        display: %w[block hidden flex inline inline-block inline-flex grid inline-grid table],
        position: %w[static relative absolute fixed sticky],
        text_align: %w[text-left text-center text-right text-justify],
        flex_direction: %w[flex-row flex-row-reverse flex-col flex-col-reverse],
        flex_wrap: %w[flex-nowrap flex-wrap flex-wrap-reverse],
        justify_content: %w[
          justify-start justify-end justify-center justify-between justify-around justify-evenly
        ],
        align_items: %w[items-start items-end items-center items-baseline items-stretch],
        place_content: %w[
          place-content-center place-content-start place-content-end place-content-between place-content-around place-content-evenly
        ],
        place_items: %w[
          place-items-start place-items-end place-items-center place-items-baseline place-items-stretch
        ],
        place_self: %w[
          place-self-auto place-self-start place-self-end place-self-center place-self-stretch
        ],
        align_content: %w[
          content-center content-start content-end content-between content-around content-evenly
        ],
        align_self: %w[
          self-auto self-start self-end self-center self-stretch self-baseline
        ],
        justify_items: %w[
          justify-items-start justify-items-end justify-items-center justify-items-stretch
        ],
        justify_self: %w[
          justify-self-auto justify-self-start justify-self-end justify-self-center justify-self-stretch
        ],
        font_size: %w[
          text-xs text-sm text-base text-lg text-xl text-2xl text-3xl text-4xl text-5xl text-6xl
        ],
        font_weight: %w[
          font-thin font-extralight font-light font-normal font-medium font-semibold font-bold
          font-extrabold font-black
        ],
        font_style: %w[italic not-italic],
        letter_spacing: %w[
          tracking-tighter tracking-tight tracking-normal tracking-wide tracking-wider tracking-widest
        ],
        line_height: %w[
          leading-none leading-tight leading-snug leading-normal leading-relaxed leading-loose
        ],
        text_decoration_line: %w[underline line-through no-underline],
        text_transform: %w[uppercase lowercase capitalize normal-case],
        text_decoration_style: %w[
          decoration-solid decoration-dashed decoration-dotted decoration-double decoration-wavy
        ],
        text_wrap: %w[break-normal break-words break-all],
        vertical_align: %w[
          align-baseline align-top align-middle align-bottom align-text-top align-text-bottom
        ],
        text_overflow: %w[truncate overflow-ellipsis overflow-clip],
        overflow: %w[
          overflow-auto overflow-hidden overflow-visible overflow-scroll
        ],
        visibility: %w[visible invisible collapse],
        border_style: %w[
          border-solid border-dashed border-dotted border-double border-none
        ],
        box_shadow: %w[
          shadow-sm shadow shadow-md shadow-lg shadow-xl shadow-2xl shadow-inner shadow-none
        ]
      }.freeze

      BREAKPOINT_ORDER = %w[sm md lg xl 2xl].freeze

      def on_send(node)
        return unless render_method?(node)

        if haml_file?
          haml_content = read_haml_file
          return unless haml_content

          check_haml_content(haml_content, node)
        elsif erb_file?
          erb_content = read_erb_file
          return unless erb_content

          check_erb_content(erb_content, node)
        end
      end

      def on_str(node)
        # Check string literals for Tailwind classes
        check_string_for_tailwind_classes(node)
      end

      private

      def render_method?(node)
        node.method_name == :render && node.arguments.any?
      end

      def check_erb_content(content, node)
        classes = extract_all_erb_classes(content)
        contradicting_classes = find_contradicting_classes(classes)

        return if contradicting_classes.empty?

        contradicting_classes.each do |group|
          add_offense(
            node,
            message: format(MSG, classes: group.join(', '))
          )
        end
      end

      def extract_all_erb_classes(content)
        classes = []
        classes.concat(extract_classes_from_html_attributes(content))
        classes.concat(extract_classes_from_rails_hash(content))
        classes.concat(extract_classes_from_rails_symbol_hash(content))
        classes.concat(extract_classes_from_content_tag(content))
        classes.concat(extract_classes_from_rails_helpers(content))
        classes.select { |cls| tailwind_class?(cls) }
      end

      def extract_classes_from_html_attributes(content)
        # Example: <div class="tw:w-1 tw:w-2"></div>
        content.scan(/class\s*=\s*['"]([^'"]+)['"]/) .flat_map { |match| match[0].split(/\s+/) }
      end

      def extract_classes_from_rails_hash(content)
        # Example: <%= radio_button_tag { class: 'tw:w-1 tw:w-2' } %>
        content.scan(/class:\s*['"]([^'"]+)['"]/) .flat_map { |match| match[0].split(/\s+/) }
      end

      def extract_classes_from_rails_symbol_hash(content)
        # Example: <%= text_field_tag( ..., :class => 'tw:w-1 tw:w-2' ) %>
        content.scan(/:class\s*=>\s*['"]([^'"]+)['"]/) .flat_map { |match| match[0].split(/\s+/) }
      end

      def extract_classes_from_content_tag(content)
        # Example: <%= content_tag :div, ..., class: 'tw:w-1 tw:w-2' %>
        content.scan(/content_tag\s+:\w+.*?class:\s*['"]([^'"]+)['"]/) .flat_map { |match| match[0].split(/\s+/) }
      end

      def extract_classes_from_rails_helpers(content)
        # Example: <%= link_to 'Name', ..., class: 'tw:w-1 tw:w-2' %>
        content.scan(/(?:link_to|form_with|form_for|button_to|submit_tag).*?class:\s*['"]([^'"]+)['"]/) .flat_map { |match| match[0].split(/\s+/) }
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

      def check_string_for_tailwind_classes(node)
        return unless node.str_type?

        content = node.value
        classes = extract_classes_from_string(content)
        contradicting_classes = find_contradicting_classes(classes)

        return if contradicting_classes.empty?

        contradicting_classes.each do |group|
          add_offense(
            node,
            message: format(MSG, classes: group.join(', '))
          )
        end
      end

      def extract_classes_from_string(content)
        # Split by whitespace and filter for Tailwind classes
        content.split(/\s+/).select { |cls| tailwind_class?(cls) }
      end

      def extract_all_classes(content)
        classes = []

        # Extract from HAML class shortcuts (e.g., %div.tw:w-1.tw:w-2)
        content.scan(/^[^#]*%\w+(?:\.[^{\s#]+)+/m) do |match|
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

      # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity
      def find_contradicting_classes(classes)
        # Remove the 'tw:' prefix for property matching
        puts "Original classes: #{classes.inspect}"
        normalized_classes = classes.map { |cls| cls.sub(matcher, '') }

        puts "Normalized classes: #{normalized_classes.inspect}"

        contradictions = []

        normalized_classes.each_with_index do |first_class, index|
          first_breakpoint_range = extract_breakpoint_range(first_class)
          first_property = extract_css_property(first_class)
          next unless valid_property?(first_property)

          classes_to_compare = normalized_classes[(index + 1)..]

          puts "classes_to_compare: #{classes_to_compare.inspect}"

          classes_to_compare.each_with_index do |second_class, j|
            second_breakpoint_range = extract_breakpoint_range(second_class)
            second_property = extract_css_property(second_class)
            next unless valid_property?(second_property)

            # Only check for contradictions if both classes are for overlapping breakpoint ranges
            next unless breakpoint_ranges_overlap?(first_breakpoint_range, second_breakpoint_range)
            next unless properties_contradict?(first_property, second_property)

            original_class = classes[index]
            contradicting_class = classes[index + j + 1]
            contradictions << [original_class, contradicting_class]
          end
        end

        contradictions
      end
      # rubocop:enable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity

      def matcher
        /^#{GIVELIVELY_TAILWIND_CLASS_PREFIX}/o
      end

      def valid_property?(property)
        property && CONTRADICTION_GROUPS.any? { |_, group| group.include?(property) }
      end

      # rubocop:disable Metrics/MethodLength
      def extract_css_property(class_name)
        # Remove breakpoint prefixes (including v4 range syntax and max-only syntax)
        class_without_breakpoint = class_name.sub(
          /^(?:(?:sm|md|lg|xl|2xl)(?::max-(?:sm|md|lg|xl|2xl))?:|max-(?:sm|md|lg|xl|2xl):)+/,
          ''
        )

        # Handle cases like 'w-1', 'mt-4', 'text-left', etc.
        patterns = [
          /^(w|h)-/,
          /^(m[trblxy]?)-/,
          /^(p[trblxy]?)-/,
          /^(block|hidden|flex|inline|inline-block|inline-flex|grid|inline-grid|table)$/,
          /^(static|relative|absolute|fixed|sticky)$/,
          /^(text-(?:left|center|right|justify))$/,
          /^(flex-(?:row|row-reverse|col|col-reverse))$/,
          /^(justify-(?:start|end|center|between|around|evenly))$/,
          /^(items-(?:start|end|center|baseline|stretch))$/,
          /^(place-content-(?:center|start|end|between|around|evenly))$/,
          /^(place-items-(?:start|end|center|baseline|stretch))$/,
          /^(place-self-(?:auto|start|end|center|stretch))$/,
          /^(content-(?:center|start|end|between|around|evenly))$/,
          /^(self-(?:auto|start|end|center|stretch|baseline))$/,
          /^(justify-items-(?:start|end|center|stretch))$/,
          /^(justify-self-(?:auto|start|end|center|stretch))$/,
          /^(text-(?:xs|sm|base|lg|xl|2xl|3xl|4xl|5xl|6xl))$/,
          /^(font-(?:thin|extralight|light|normal|medium|semibold|bold|extrabold|black))$/,
          /^(italic|not-italic)$/,
          /^(tracking-(?:tighter|tight|normal|wide|wider|widest))$/,
          /^(leading-(?:none|tight|snug|normal|relaxed|loose))$/,
          /^(underline|line-through|no-underline)$/,
          /^(uppercase|lowercase|capitalize|normal-case)$/,
          /^(decoration-(?:solid|dashed|dotted|double|wavy))$/,
          /^(break-(?:normal|words|all))$/,
          /^(align-(?:baseline|top|middle|bottom|text-top|text-bottom))$/,
          /^(truncate|overflow-(?:ellipsis|clip))$/,
          /^(overflow-(?:auto|hidden|visible|scroll))$/,
          /^(visible|invisible|collapse)$/,
          /^(border-(?:solid|dashed|dotted|double|none))$/,
          /^(shadow(?:-(?:sm|md|lg|xl|2xl|inner|none))?)$/
        ]

        patterns.each do |pattern|
          match = class_without_breakpoint.match(pattern)
          return match[1] if match
        end

        nil
      end
      # rubocop:enable Metrics/MethodLength

      def extract_breakpoint_range(class_name)
        # Extract breakpoint range (e.g., 'md', 'lg:max-xl', 'sm:max-md')
        # Returns a hash with :min and :max keys, or nil if no breakpoint

        # Match Tailwind v4 range syntax: breakpoint:max-breakpoint: or just breakpoint:
        range_match = class_name.match(/^(sm|md|lg|xl|2xl)(?::max-(sm|md|lg|xl|2xl))?:/)
        return nil unless range_match

        min_breakpoint = range_match[1]
        max_breakpoint = range_match[2]

        {
          min: min_breakpoint,
          max: max_breakpoint
        }
      end

      # rubocop:disable Metrics/CyclomaticComplexity, Metrics/AbcSize
      def breakpoint_ranges_overlap?(first_range, second_range)
        # If either range is nil (no breakpoint), they're considered the same (base styles)
        return true if first_range.nil? && second_range.nil?
        return false if first_range.nil? || second_range.nil?

        # Get numeric indices for comparison
        first_min_index = BREAKPOINT_ORDER.index(first_range[:min])
        first_max_index = first_range[:max] ? BREAKPOINT_ORDER.index(first_range[:max]) : BREAKPOINT_ORDER.length - 1

        second_min_index = BREAKPOINT_ORDER.index(second_range[:min])
        second_max_index = second_range[:max] ? BREAKPOINT_ORDER.index(second_range[:max]) : BREAKPOINT_ORDER.length - 1

        # Check for overlap: ranges overlap if one starts before the other ends
        !(first_max_index < second_min_index || second_max_index < first_min_index)
      end

      def properties_contradict?(first_prop, second_prop)
        first_prop_group = CONTRADICTION_GROUPS.select { |_, group| group.include?(first_prop) }.keys
        second_prop_group = CONTRADICTION_GROUPS.select { |_, group| group.include?(second_prop) }.keys

        return false unless first_prop_group && second_prop_group

        puts "Comparing properties: #{first_prop} (group: #{first_prop_group}) vs #{second_prop} (group: #{second_prop_group})"

        # Check if both properties belong to the same contradicting group
        first_prop_group.intersect?(second_prop_group)
      end
      # rubocop:enable Metrics/CyclomaticComplexity, Metrics/AbcSize
    end
    # rubocop:enable Metrics/ClassLength
  end
end
