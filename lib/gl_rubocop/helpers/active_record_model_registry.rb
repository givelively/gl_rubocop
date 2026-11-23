require 'set'
require 'parser/current'

module GLRubocop
  module Helpers
    class ActiveRecordModelRegistry
      DEFAULT_GLOBS = [
        'app/models/**/*.rb',
        'packs/*/app/models/**/*.rb'
      ].freeze

      ALL_MODEL_GLOBS = [
        'app/models/**/*.rb',
        'packs/*/app/models/**/*.rb',
        'packs/*/app/public/**/*.rb'
      ].freeze

      AR_BASE_CLASSES = ['ApplicationRecord', 'ActiveRecord::Base'].freeze

      class << self
        def for(project_root:, globs: DEFAULT_GLOBS)
          @cache ||= {}
          @cache[[project_root,
                  globs]] ||= new(project_root:, globs:).model_names
        end

        def database_groups_for(project_root:, globs: ALL_MODEL_GLOBS,
                                non_primary_base_classes: {}, non_primary_models: {})
          @db_cache ||= {}
          key = [project_root, globs, non_primary_base_classes, non_primary_models]
          @db_cache[key] ||= new(project_root:, globs:).database_groups(
            non_primary_base_classes:,
            non_primary_models:
          )
        end

        def reset_cache!
          @cache = {}
          @db_cache = {}
        end
      end

      def initialize(project_root:, globs:)
        @project_root = project_root
        @globs = globs
      end

      def model_names
        Set.new(database_groups.keys)
      end

      def database_groups(non_primary_base_classes: {}, non_primary_models: {})
        parents = collect_class_parents
        explicit_db = build_explicit_db(non_primary_base_classes, non_primary_models)
        seen = {}
        (parents.keys | explicit_db.keys).each_with_object({}) do |name, result|
          db = resolve_db_group(name, parents, explicit_db, seen)
          result[name] = db if db
        end
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
        record_class_parent(name.join('::'), node.children[1], namespace, parents)
        walk_body(node.children[2], name, parents)
      end

      def record_class_parent(full_name, super_node, namespace, parents)
        return unless super_node || !parents.key?(full_name)

        parents[full_name] = {
          parent: super_node && const_name(super_node),
          namespace:,
          parent_anchored: anchored_at_cbase?(super_node)
        }
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

      def anchored_at_cbase?(node)
        current = node
        current = current.children[0] while current&.type == :const
        current&.type == :cbase
      end

      def build_explicit_db(non_primary_base_classes, non_primary_models)
        explicit_db = {}
        [non_primary_base_classes, non_primary_models].each do |mapping|
          mapping.each do |db, klasses|
            Array(klasses).each { |klass| explicit_db[klass.to_s] = db.to_sym }
          end
        end
        explicit_db
      end

      def resolve_db_group(name, parents, explicit_db, seen)
        return seen[name] if seen.key?(name)
        return explicit_db[name] if explicit_db.key?(name)
        return :primary if AR_BASE_CLASSES.include?(name)

        info = parents[name]
        return nil unless info

        seen[name] = nil
        parent = info[:parent]
        return nil unless parent

        resolved_parent = resolve_const(parent, info[:namespace], parents,
                                        anchored: info[:parent_anchored])
        seen[name] = resolve_db_group(resolved_parent, parents, explicit_db, seen)
      end

      def resolve_const(name, namespace, parents, anchored: false)
        return name if anchored

        namespace.size.downto(0) do |i|
          candidate = (namespace[0...i] + [name]).join('::')
          return candidate if parents.key?(candidate)
        end
        name
      end
    end
  end
end
