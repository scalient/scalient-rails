# -*- coding: utf-8 -*-
#
# Copyright 2014 Scalient LLC
# All rights reserved.

require "active_support/concern"

module Scalient
  module Rails
    module ApplicationHelpers
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
      end
    end
  end
end
