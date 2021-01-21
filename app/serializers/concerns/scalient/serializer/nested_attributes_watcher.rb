# frozen_string_literal: true
#
# Copyright 2020 Scalient LLC
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

module Scalient
  module Serializer
    module NestedAttributesWatcher
      extend ActiveSupport::Concern

      included do
        attr_reader :updated_nested_associations

        singleton_class.send(:prepend, ClassMethods)

        send(:prepend, InstanceMethods)

        # Scan the existing `accepts_nested_attributes_for` declarations and overwrite the existing setters.
        redefine_nested_attributes_setters(*nested_attributes_options.keys.map(&:to_sym))
      end

      module InstanceMethods
        def mark_nested_association_for_update(name)
          @updated_nested_associations ||= Set.new
          @updated_nested_associations.add(name.to_s)
        end

        def nested_association_was_updated?(name)
          if @updated_nested_associations
            @updated_nested_associations.include?(name.to_s)
          else
            false
          end
        end

        def has_updated_nested_associations?
          !!@updated_nested_associations
        end

        def reload(options = nil)
          super(options).tap do |_|
            @updated_nested_associations = nil
          end
        end
      end

      module ClassMethods
        def accepts_nested_attributes_for(*attrs)
          super(*attrs).tap do |_|
            attrs.extract_options!
            redefine_nested_attributes_setters(*attrs)
          end
        end

        # We deliberately avoid the preferred `prepend` strategy to not excessively pollute the ancestry chain with a
        # potentially large number of `accepts_nested_attributes_for` declarations.
        def redefine_nested_attributes_setters(*reflection_names)
          reflection_names.each do |reflection_name|
            setter_name = "#{reflection_name}_attributes="
            unbound_setter = instance_method(setter_name)

            define_method(setter_name) do |*attrs|
              unbound_setter.bind(self).call(*attrs)
              mark_nested_association_for_update(reflection_name)
            end
          end
        end
      end
    end
  end
end
