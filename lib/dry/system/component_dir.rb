require "pathname"
require_relative "constants"
require_relative "magic_comments_parser"

module Dry
  module System
    # A configured component directory within the container's root. Provides access to the
    # component directory's configuration, as well as methods for locating component files
    # within the directory
    #
    # @see Dry::System::Config::ComponentDir
    # @api private
    class ComponentDir
      # @!attribute [r] config
      #   @return [Dry::System::Config::ComponentDir] the component directory configuration
      #   @api private
      attr_reader :config

      # @!attribute [r] container
      #   @return [Dry::System::Container] the container managing the component directory
      #   @api private
      attr_reader :container

      # @api private
      def initialize(config:, container:)
        @config = config
        @container = container
      end

      def component_from_identifier(identifier)
        path, namespace = find_component_file(identifier)

        if path
          build_component(identifier, path, namespace: namespace)
        end
      end

      def component_from_path(path)
        # TODO: raise error if the path is not in the component dir's full_path?
        # Though this will add an extra check for every component when auto-registering

        relative_path = Pathname(path).relative_path_from(full_path).sub(RB_EXT, EMPTY_STRING).to_s

        identifier = relative_path.scan(WORD_REGEX).join(container.config.namespace_separator)
        namespace = nil

        if default_namespace
          namespace_match = identifier.match(/^(?<remove_namespace>#{default_namespace})(?<separator>\W)(?<identifier>.*)/)

          if namespace_match&.[](:identifier)
            identifier = namespace_match[:identifier]
            namespace = default_namespace
          end
        end

        build_component(identifier, path.to_s, namespace: namespace)
      end

      # Returns the full path of the component directory
      #
      # @return [Pathname]
      # @api private
      def full_path
        container.root.join(path)
      end

      # Returns the explicitly configured loader for the component dir, otherwise the
      # default loader configured for the container
      #
      # @see Dry::System::Loader
      # @api private
      def loader
        config.loader || container.config.loader
      end

      # @api private
      def component_options
        {
          auto_register: auto_register,
          loader: loader,
          memoize: memoize,
        }
      end

      private

      def build_component(identifier, file_path, options = EMPTY_HASH)
        options = {
          inflector: container.config.inflector,
          separator: container.config.namespace_separator,
          **options,
          **component_options,
          **MagicCommentsParser.(file_path)
        }

        Component.new(identifier, file_path: file_path, **options)
      end


      def find_component_file(identifier)
        separator = container.config.namespace_separator

        component_path = identifier.to_s.gsub(separator, PATH_SEPARATOR)

        if default_namespace
          namespace_path = default_namespace.gsub(separator, PATH_SEPARATOR)
          namespaced_component_path = "#{namespace_path}#{PATH_SEPARATOR}#{component_path}"

          if (component_file = component_file(namespaced_component_path))
            return [component_file, default_namespace]
          end
        end

        if (component_file = component_file(component_path))
          return [component_file, nil]
        end
      end

      # Returns the full path for a component file within the directory, or nil if none if
      # exists
      #
      # @return [Pathname, nil]
      # @api private

      # FIXME: temporarily public until I update unit tests
      public def component_file(component_path)
        component_file = full_path.join("#{component_path}#{RB_EXT}")
        component_file if component_file.exist?
      end

      def method_missing(name, *args, &block)
        if config.respond_to?(name)
          config.public_send(name, *args, &block)
        else
          super
        end
      end

      def respond_to_missing?(name, include_all = false)
        config.respond_to?(name) || super
      end
    end
  end
end
