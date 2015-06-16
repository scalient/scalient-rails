# -*- coding: utf-8 -*-
#
# Copyright 2015 Scalient LLC
# All rights reserved.

require "active_support/concern"

module Scalient
  module Rails
    module SprocketsHelper
      extend ActiveSupport::Concern

      included do
        raise "Please mix this module into `Sprockets::Environment` or `Sprockets::CachedEnvironment`" \
          if self != Sprockets::Environment && self != Sprockets::CachedEnvironment

        def copy(context_values = {}, &block)
          app = ::Rails.application
          original_env = self

          Sprockets::Environment.new(original_env.root) do |env|
            env.version = ::Rails.env.to_s

            env.context_class.class_eval do
              # Import helpers from the `sprockets-rails` gem.
              include Sprockets::Rails::Helper

              metaclass = class << self
                extend Forwardable

                def_delegators :application, :assets_manifest
                def_delegators :original, :assets_prefix, :config, :digest_assets

                self
              end

              metaclass.send(:define_method, :application) { app }
              metaclass.send(:define_method, :original) { original_env.context_class }

              # Expose user-defined context values as methods.
              context_values.each_pair { |key, value| define_method(key.to_sym) { value } }
            end

            # Inherit the original environment's paths. These can be overridden with `clear_paths`.
            original_env.paths.each { |path| env.append_path(path) }

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
