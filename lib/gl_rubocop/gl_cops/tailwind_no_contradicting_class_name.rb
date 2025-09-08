# frozen_string_literal: true

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
      MSG = 'Contradicting Tailwind CSS classes found: %<classes>s both affect the same CSS property'
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

      def haml_file?
        file_path = processed_source.file_path
        file_path&.end_with?('.html.haml') && File.exist?(file_path)
      end

      def read_haml_file
        File.read(processed_source.file_path)
      rescue StandardError
        nil
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

      def find_contradicting_classes(classes)
        matcher = /^#{GIVELIVELY_TAILWIND_CLASS_PREFIX}/o
        # Remove the 'tw:' prefix for property matching
        normalized_classes = classes.map { |cls| cls.sub(matcher, '') }

        contradictions = []

        normalized_classes.each_with_index do |class1, i|
          property1 = extract_property(class1)
          next unless property1 && PROPERTY_GROUPS[property1]

          normalized_classes[(i + 1)..-1].each_with_index do |class2, j|
            property2 = extract_property(class2)
            next unless property2

            if properties_contradict?(property1, property2)
              original_class1 = classes[i]
              original_class2 = classes[i + j + 1]
              contradictions << [original_class1, original_class2]
            end
          end
        end

        contradictions
      end

      def extract_property(class_name)
        # Handle cases like 'w-1', 'mt-4', 'text-left', etc.
        case class_name
        when /^(w|h)-/
          $1
        when /^(m[trbllxy]?)-/
          $1
        when /^(p[trbllxy]?)-/
          $1
        when /^(block|hidden|flex|inline|inline-block|inline-flex|grid|inline-grid|table)$/
          $1
        when /^(static|relative|absolute|fixed|sticky)$/
          $1
        when /^(text-(?:left|center|right|justify))$/
          $1
        when /^(flex-(?:row|row-reverse|col|col-reverse))$/
          $1
        when /^(justify-(?:start|end|center|between|around|evenly))$/
          $1
        end
      end

      def properties_contradict?(prop1, prop2)
        group1 = PROPERTY_GROUPS[prop1]
        group2 = PROPERTY_GROUPS[prop2]

        return false unless group1 && group2

        # Check if both properties belong to the same contradicting group
        (group1 & group2).any?
      end
    end
  end
end
