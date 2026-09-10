require 'parser/current'

module GLRubocop
  module Helpers
    # Scans a project's packs for controller classes and maps each controller's Rails
    # controller path (e.g. `'receipt_copy/receipts'`) to the name of the pack that
    # defines it. Controller paths are derived from the controller's fully namespaced
    # class name (mirroring how Rails computes `controller_path`), not from the file's
    # location on disk, since some packs place controllers under `app/public` instead
    # of `app/controllers`.
    class PackControllerRegistry
      DEFAULT_GLOBS = [
        'packs/*/app/controllers/**/*.rb',
        'packs/*/app/public/**/*_controller.rb'
      ].freeze

      class << self
        def for(project_root:, globs: DEFAULT_GLOBS)
          @cache ||= {}
          @cache[[project_root, globs]] ||= new(project_root:, globs:).controller_packs
        end

        def reset_cache!
          @cache = {}
        end
      end

      def initialize(project_root:, globs:)
        @project_root = project_root
        @globs = globs
      end

      # Returns a Hash of controller_path (String) => pack_name (String)
      def controller_packs
        mapping = {}
        globs.each do |glob|
          Dir.glob(File.join(project_root, glob)).each { |path| collect(path, mapping) }
        end
        mapping
      end

      private

      attr_reader :project_root, :globs

      def collect(path, mapping)
        return unless File.file?(path)

        pack_name = pack_name_for(path)
        return unless pack_name

        controller_paths_in(path).each { |controller_path| mapping[controller_path] = pack_name }
      end

      def pack_name_for(path)
        relative = path.delete_prefix("#{project_root}/")
        match = relative.match(%r{\Apacks/([^/]+)/})
        match && match[1]
      end

      def controller_paths_in(path)
        ast = parse(path)
        return [] unless ast

        paths = []
        walk_classes(ast, [], paths)
        paths
      end

      def parse(path)
        Parser::CurrentRuby.parse(File.read(path))
      rescue Parser::SyntaxError, EncodingError
        nil
      end

      def walk_classes(node, namespace, paths)
        return unless node.is_a?(Parser::AST::Node)

        case node.type
        when :module
          walk_body(node.children[1], namespace + [const_name(node.children[0])], paths)
        when :class
          walk_class(node, namespace, paths)
        else
          node.children.each do |child|
            walk_classes(child, namespace, paths) if child.is_a?(Parser::AST::Node)
          end
        end
      end

      def walk_class(node, namespace, paths)
        full_name = (namespace + [const_name(node.children[0])]).join('::')
        paths << controller_path_for(full_name) if full_name.end_with?('Controller')
        walk_body(node.children[2], namespace + [const_name(node.children[0])], paths)
      end

      def walk_body(body, namespace, paths)
        return unless body

        if body.type == :begin
          body.children.each { |child| walk_classes(child, namespace, paths) }
        else
          walk_classes(body, namespace, paths)
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

      def controller_path_for(full_class_name)
        underscore(full_class_name.delete_suffix('Controller'))
      end

      def underscore(camel_cased_word)
        camel_cased_word.gsub('::', '/')
                        .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
                        .gsub(/([a-z\d])([A-Z])/, '\1_\2')
                        .tr('-', '_')
                        .downcase
      end
    end
  end
end
