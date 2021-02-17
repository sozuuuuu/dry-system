# frozen_string_literal: true

require "concurrent/map"

require "dry-equalizer"
require "dry/inflector"
require "dry/system/loader"
require "dry/system/errors"
require "dry/system/constants"

module Dry
  module System
    # Components are objects providing information about auto-registered files.
    # They expose an API to query this information and use a configurable
    # loader object to initialize class instances.
    #
    # @api public
    class Component
      include Dry::Equalizer(:identifier, :path, :file_path, :options)

      DEFAULT_OPTIONS = {
        separator: DEFAULT_SEPARATOR,
        inflector: Dry::Inflector.new,
        loader: Loader
      }.freeze

      # @!attribute [r] identifier
      #   @return [String] component's unique identifier
      attr_reader :identifier

      # @!attribute [r] path
      #   @return [String] component's relative path
      attr_reader :path

      # @!attribute [r] file_path
      #   @return [String, nil] full path to the component's file, if found
      attr_reader :file_path

      # @!attribute [r] options
      #   @return [Hash] component's options
      attr_reader :options

      # @api private
      def self.new(identifier, options = EMPTY_HASH)
        options = DEFAULT_OPTIONS.merge(options)

        namespace, separator = options.values_at(:namespace, :separator)

        identifier = extract_identifier(identifier, namespace, separator)

        path = identifier.gsub(separator, PATH_SEPARATOR)
        if namespace
          namespace = namespace.to_s.gsub(separator, PATH_SEPARATOR)
          path = "#{namespace}#{PATH_SEPARATOR}#{path}"
        end

        super(identifier, path: path, **options)
      end

      # @api private
      def self.extract_identifier(identifier, namespace, separator)
        identifier = identifier.to_s

        identifier = namespace ? remove_namespace_from_name(identifier, namespace) : identifier

        identifier.scan(WORD_REGEX).join(separator)
      end
      private_class_method :extract_identifier

      # @api private
      def self.remove_namespace_from_name(name, namespace)
        match_value = name.match(/^(?<remove_namespace>#{namespace})(?<separator>\W)(?<identifier>.*)/)

        # if match_value
        #   puts "Removing #{namespace} from #{name} -> #{match_value[:identifier]}"
        # end

        match_value ? match_value[:identifier] : name
      end
      private_class_method :remove_namespace_from_name

      # @api private
      def initialize(identifier, path:, file_path: nil, **options)
        @identifier = identifier
        @path = path
        @file_path = file_path
        @options = options
        freeze
      end

      # Returns the component's instance
      #
      # @return [Object] component's class instance
      # @api public
      def instance(*args)
        loader.call(self, *args)
      end
      ruby2_keywords(:instance) if respond_to?(:ruby2_keywords, true)

      # @api private
      def bootable?
        false
      end

      # Returns true if the component has a corresponding file
      #
      # @return [Boolean]
      # @api private
      def file_exists?
        !!file_path
      end

      # @api private
      def namespaced(namespace)
        self.class.new(
          identifier,
          path: path,
          file_path: nil,
          **options,
          namespace: namespace,
        )
      end

      # @api private
      def loader
        options[:loader]
      end

      # @api private
      def inflector
        options[:inflector]
      end

      # @api private
      def separator
        options[:separator]
      end

      # @api private
      def namespace
        options[:namespace]
      end

      # @api private
      def auto_register?
        callable_option?(options[:auto_register])
      end

      # @api private
      def memoize?
        callable_option?(options[:memoize])
      end

      # @api private
      def root_key
        identifier.split(separator).map(&:to_sym).first
      end

      private

      def callable_option?(value)
        if value.respond_to?(:call)
          !!value.call(self)
        else
          !!value
        end
      end
    end
  end
end
