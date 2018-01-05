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
          yaml_content = YAML.load(file.open {|f| f.read})

          raise ArgumentError, "Top-level YAML object must be a Hash" \
            if !yaml_content.is_a?(Hash) && !yaml_content.nil?

          method_name = file.sub_ext("").basename

          if config.respond_to?(:"#{method_name}")
            oo = config.send(:"#{method_name}")
          else
            oo = ActiveSupport::OrderedOptions.new
            config.send(:"#{method_name}=", oo)
          end

          (yaml_content || {}).each_pair {|k, v| oo[k] = v}

          oo
        end

        # Creates a copy of the assets environment for specialized compilation and templating operations.
        #
        # @yield Configure the environment further.
        #
        # @return [Sprockets::Environment] a copy of the assets environment.
        def copy_assets(&block)
          app = ::Rails.application

          ::Sprockets::Environment.new(app.root.to_s) do |env|
            env.version = ::Rails.env.to_s

            env.context_class.class_eval do
              # Import some voodoo from Sprockets Rails. See
              # `https://github.com/rails/sprockets-rails/blob/v3.2.0/lib/sprockets/railtie.rb#L132-L135`.
              include ::Sprockets::Rails::Context

              self.assets_prefix = app.config.assets.prefix
              self.digest_assets = app.config.assets.digest
              self.config = app.config.action_controller
            end

            # Use the application configuration's search paths. These can be overridden with `clear_paths`.
            app.config.assets.paths.each {|path| env.append_path(path)}

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
