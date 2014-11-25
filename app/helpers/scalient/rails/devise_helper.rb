# -*- coding: utf-8 -*-
#
# Copyright 2014 Roy Liu
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not
# use this file except in compliance with the License. You may obtain a copy of
# the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations under
# the License.

require "devise"
require "i18n"
require "yaml"

module Scalient
  module Rails
    module DeviseHelper
      module InstanceMethods
        def copy_devise_superclass_i18n_translations
          return \
            if !ancestors.include?(DeviseController)

          Pathname.glob("#{Devise::Engine.root.to_s}/config/locales/*.yml").each do |locale_file|
            YAML.load(locale_file.open("rb") { |f| f.read }).each do |locale, locale_data|
              I18n.backend.store_translations(locale, {
                  "devise" => {
                      controller_name => locale_data["devise"][superclass.controller_name]
                  }
              })
            end
          end
        end
      end

      def self.included(klass)
        klass.send(:include, InstanceMethods)
      end
    end
  end
end
