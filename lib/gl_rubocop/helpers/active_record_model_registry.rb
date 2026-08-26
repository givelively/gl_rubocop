# frozen_string_literal: true

require 'set'
require 'parser/current'

module GLRubocop
  module Helpers
    # Scans a host application's model files to determine which constants transitively
    # inherit from ApplicationRecord/ActiveRecord::Base.
    #
    # This exists because directories like app/models commonly hold plain Ruby objects
    # (wrappers, value objects, wrapped API responses) alongside real ActiveRecord
    # models, so a class's location alone doesn't tell us whether using it directly in
    # a controller is actually a database-layer/networking-layer violation.
    class ActiveRecordModelRegistry
      DEFAULT_GLOBS = [
        'app/models/**/*.rb',
        'packs/*/app/models/**/*.rb'
      ].freeze

      AR_BASE_CLASSES = ['ApplicationRecord', 'ActiveRecord::Base'].freeze

      class << self
        # Memoized per (project_root, globs), so the filesystem is scanned once per
        # RuboCop process no matter how many controller files are linted.
        def for(project_root:, globs: DEFAULT_GLOBS)
          @cache ||= {}
          @cache[[project_root,
                  globs]] ||= new(project_root:, globs:).model_names
        end

        def reset_cache!
          @cache = {}
        end
      end

      def initialize(project_root:, globs:)
        @project_root = project_root
        @globs = globs
      end

      # Returns a Set of fully-qualified AR-derived model names, e.g.
      # #<Set: {"Nonprofit", "Webhook::Endpoint", "Datawarehouse::BaseRecord"}>
      def model_names
        parents = collect_class_parents
        Set.new(parents.keys.select { |name| ar_derived?(name, parents) })
      end

      private

      attr_reader :project_root, :globs

      def collect_class_parents
        parents = {}
        globs.each do |glob|
          Dir.glob(File.join(project_root, glob)).each do |path|
            next unless File.file?(path)

            walk_classes(parse(path), [], parents)
          end
        end
        parents
      end

      # A syntax error in an unrelated model file should never crash the lint run of
      # the controller currently being checked.
      def parse(path)
        Parser::CurrentRuby.parse(File.read(path))
      rescue Parser::SyntaxError, EncodingError
        nil
      end

      def walk_classes(node, namespace, parents)
        return unless node.is_a?(Parser::AST::Node)

        case node.type
        when :module
          walk_module(node, namespace, parents)
        when :class
          walk_class(node, namespace, parents)
        else
          walk_children(node, namespace, parents)
        end
      end

      def walk_module(node, namespace, parents)
        walk_body(node.children[1], namespace + [const_name(node.children[0])], parents)
      end

      def walk_class(node, namespace, parents)
        name = namespace + [const_name(node.children[0])]
        parent = node.children[1] && const_name(node.children[1])
        parents[name.join('::')] = { parent:, namespace: }
        walk_body(node.children[2], name, parents)
      end

      def walk_children(node, namespace, parents)
        node.children.each do |child|
          walk_classes(child, namespace, parents) if child.is_a?(Parser::AST::Node)
        end
      end

      def walk_body(body, namespace, parents)
        return unless body

        if body.type == :begin
          body.children.each { |child| walk_classes(child, namespace, parents) }
        else
          walk_classes(body, namespace, parents)
        end
      end

      def const_name(node)
        return nil unless node

        parts = []
        current = node
        while current&.type == :const
          parts.unshift(current.children[1].to_s)
          current = current.children[0]
        end
        parts.join('::')
      end

      def ar_derived?(name, parents, seen = {})
        return seen[name] if seen.key?(name)
        return true if AR_BASE_CLASSES.include?(name)

        info = parents[name]
        return false unless info

        seen[name] = false # guards against inheritance cycles
        parent = info[:parent]
        return false unless parent

        resolved_parent = resolve_const(parent, info[:namespace], parents)
        result = ar_derived?(resolved_parent, parents, seen)
        seen[name] = result
        result
      end

      # Approximates Ruby's constant lookup: search the enclosing namespaces outward
      # before falling back to the bare name.
      def resolve_const(name, namespace, parents)
        return name if parents.key?(name)

        namespace.size.downto(0) do |i|
          candidate = (namespace[0...i] + [name]).join('::')
          return candidate if parents.key?(candidate)
        end
        name
      end
    end
  end
end
