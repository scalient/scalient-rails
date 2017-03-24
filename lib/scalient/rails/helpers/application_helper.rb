# -*- coding: utf-8 -*-
#
# Copyright 2014 Scalient LLC
# All rights reserved.

require "active_support/concern"

module Scalient
  module Rails
    module ApplicationHelper
      extend ActiveSupport::Concern

      included do
        # Loads the given YAML configuration file.
        #
        # @param filename [String] the filename.
        #
        # @return [ActiveSupport::OrderedOptions] the configuration values.
        def load_yaml(filename)
          file = Pathname.new(filename).expand_path(::Rails.root)
          yaml_content = YAML.load(file.open { |f| f.read })

          raise ArgumentError, "Top-level YAML object must be a Hash" \
            if !yaml_content.is_a?(Hash) && !yaml_content.nil?

          method_name = file.sub_ext("").basename

          if config.respond_to?(:"#{method_name}")
            oo = config.send(:"#{method_name}")
          else
            oo = ActiveSupport::OrderedOptions.new
            config.send(:"#{method_name}=", oo)
          end

          (yaml_content || {}).each_pair { |k, v| oo[k] = v }

          oo
        end

        # Creates a copy of the assets environment for specialized compilation and templating operations.
        #
        # @param context_values [Hash] custom context values that will be made available to templates and such.
        # @yield Configure the environment further.
        #
        # @return [Sprockets::Environment] a copy of the assets environment.
        def copy_assets(context_values = {}, &block)
          app = ::Rails.application

          Sprockets::Environment.new(app.root.to_s) do |env|
            env.version = ::Rails.env.to_s

            env.context_class.class_eval do
              # Import helpers from the `sprockets-rails` gem.
              include Sprockets::Rails::Helper

              metaclass = class << self
                extend Forwardable

                def_delegators :application, :assets_manifest

                self
              end

              metaclass.send(:define_method, :application) { app }

              # Expose user-defined context values as methods.
              context_values.each_pair { |key, value| define_method(key.to_sym) { value } }
            end

            # Inherit the original environment's paths. These can be overridden with `clear_paths`.
            app.config.assets.paths.each { |path| env.append_path(path) }

            # Since this is mostly likely a single-use environment, we don't intend to cache anything.
            env.cache = nil

            # No CSS compression.
            env.css_compressor = nil

            # No JS compression.
            env.js_compressor = nil

            # Enable further customization by the user.
            block.call(env) \
              if block
          end
        end
      end
    end
  end
end
