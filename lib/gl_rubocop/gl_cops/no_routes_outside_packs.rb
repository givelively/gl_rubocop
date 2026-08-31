require_relative '../helpers/pack_controller_registry'

module GLRubocop
  module GLCops
    # This cop flags route declarations for a pack-based controller when those routes
    # are not defined within that pack's own routes file.
    #
    # Per our controller standards RFC, route declarations should live alongside the
    # controllers they serve, so the relationship between routes and controllers stays
    # clear and the codebase is easier to navigate.
    #
    # Only routes that resolve (via an explicit `to:`/`controller:` option, or an
    # implicit `resources`/`resource` name) to a controller that lives in a pack are
    # checked; routes for controllers outside of packs are always ignored. Pre-existing
    # violations can be grandfathered in via the `Grandfathered` option (a list of
    # controller paths, e.g. `receipt_copy/receipts`) so only newly introduced
    # violations are flagged.
    #
    # Good:
    #   # packs/tracking/config/routes/tracking.rb (packs/tracking/app/controllers/events_controller.rb)
    #   namespace :tracking do
    #     resources :events, only: :create
    #   end
    #
    # Bad:
    #   # config/routes.rb, for a controller defined in packs/tracking
    #   namespace :tracking do
    #     resources :events, only: :create
    #   end
    class NoRoutesOutsidePacks < RuboCop::Cop::Base
      MSG = 'Routes for the `%<controller>s` controller must be defined in ' \
            '%<expected_path>s (packs/%<pack>s), not here.'.freeze

      NAMESPACING_METHODS = %i[namespace scope].freeze
      RESOURCE_METHODS = %i[resources resource].freeze
      MEMBER_ROUTE_METHODS = %i[get post put patch delete match].freeze

      DEFAULT_ROUTES_PATH_TEMPLATE = 'packs/%<pack>s/public/config/routes.rb'.freeze

      def on_new_investigation
        walk(processed_source.ast, [])
      end

      private

      def walk(node, namespace)
        return unless node.is_a?(RuboCop::AST::Node)

        if node.block_type?
          walk_block(node, namespace)
        elsif node.send_type?
          check_route(node, namespace)
          walk_children(node, namespace)
        else
          walk_children(node, namespace)
        end
      end

      def walk_children(node, namespace)
        node.children.each { |child| walk(child, namespace) if child.is_a?(RuboCop::AST::Node) }
      end

      def walk_block(node, namespace)
        send_node = node.send_node
        check_route(send_node, namespace)

        child_namespace = namespace + Array(namespace_segment_for(send_node))
        walk(node.body, child_namespace) if node.body
      end

      def check_route(send_node, namespace)
        return unless send_node&.send_type?

        if RESOURCE_METHODS.include?(send_node.method_name)
          check_resource(send_node, namespace)
        elsif MEMBER_ROUTE_METHODS.include?(send_node.method_name)
          check_member_route(send_node, namespace)
        end
      end

      def check_member_route(send_node, namespace)
        to_value = keyword_value(send_node, :to)
        return unless to_value&.str_type?

        controller_part = to_value.value.to_s.split('#').first
        return if controller_part.nil? || controller_part.empty?

        check_controller_path(send_node, build_controller_path(namespace, controller_part))
      end

      def check_resource(send_node, namespace)
        controller_part = explicit_controller_option(send_node) || resource_name_for(send_node)
        return unless controller_part

        check_controller_path(send_node, build_controller_path(namespace, controller_part))
      end

      def explicit_controller_option(send_node)
        value = keyword_value(send_node, :controller)
        value.value.to_s if value&.str_type?
      end

      def resource_name_for(send_node)
        first_arg = send_node.arguments.first
        return nil unless first_arg && (first_arg.sym_type? || first_arg.str_type?)

        name = first_arg.value.to_s
        send_node.method_name == :resource ? pluralize(name) : name
      end

      def namespace_segment_for(send_node)
        return nil unless send_node&.send_type?

        case send_node.method_name
        when :namespace
          first_arg = send_node.arguments.first
          first_arg.value.to_s if first_arg && (first_arg.sym_type? || first_arg.str_type?)
        when :scope
          module_value = keyword_value(send_node, :module)
          module_value.value.to_s if module_value&.str_type?
        end
      end

      def keyword_value(send_node, key)
        hash_arg = send_node.arguments.find { |arg| arg.hash_type? }
        return nil unless hash_arg

        pair = hash_arg.pairs.find { |p| p.key.sym_type? && p.key.value == key }
        pair&.value
      end

      def build_controller_path(namespace, controller_part)
        return controller_part.delete_prefix('/') if controller_part.start_with?('/')

        (namespace + [controller_part]).join('/')
      end

      def check_controller_path(node, controller_path)
        pack_name = controller_packs[controller_path]
        return unless pack_name
        return if grandfathered.include?(controller_path)
        return if defined_in_owning_pack_routes_file?(pack_name)

        add_offense(node, message: format(MSG,
                                           controller: controller_path,
                                           pack: pack_name,
                                           expected_path: format(routes_path_template, pack: pack_name)))
      end

      def defined_in_owning_pack_routes_file?(pack_name)
        expected_suffix = format(routes_path_template, pack: pack_name)
        processed_source.path.to_s.end_with?(expected_suffix)
      end

      def pluralize(word)
        return "#{word.delete_suffix('y')}ies" if word.end_with?('y') && !word.end_with?(*%w[ay ey iy oy uy])
        return "#{word}es" if word.end_with?('s', 'x', 'z', 'ch', 'sh')

        "#{word}s"
      end

      def controller_packs
        GLRubocop::Helpers::PackControllerRegistry.for(project_root:, globs: controller_globs)
      end

      def project_root
        RuboCop::ConfigFinder.project_root
      end

      def controller_globs
        cop_config.fetch('ControllerGlobs', GLRubocop::Helpers::PackControllerRegistry::DEFAULT_GLOBS)
      end

      def routes_path_template
        cop_config.fetch('RoutesPathTemplate', DEFAULT_ROUTES_PATH_TEMPLATE)
      end

      def grandfathered
        cop_config.fetch('Grandfathered', [])
      end
    end
  end
end
