# frozen_string_literal: true

# Copyright 2024 Roy Liu
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
  module ActiveRecord
    module NestedAttributesCapturing
      extend ActiveSupport::Concern

      included do
        if !include?(NestedAttributesCallbacks)
          send(:include, NestedAttributesCallbacks)
        end

        send(:prepend, InstanceMethods)

        attr_reader :nested_reflections_to_records
      end

      module InstanceMethods
        def nested_reflection_names_to_record_statuses
          @nested_reflection_names_to_record_statuses ||= {}
        end

        def record_statuses_for_nested_reflection_name(reflection_name)
          reflection = self.class.reflections[reflection_name.to_s]

          initial_value = if reflection.collection?
            []
          else
            nil
          end

          nested_reflection_names_to_record_statuses[reflection_name] ||= initial_value
        end

        def register_record_status_for_nested_reflection(reflection_name, record, status)
          record_statuses = nested_reflection_names_to_record_statuses[reflection_name]

          if record_statuses.is_a?(Array)
            record_statuses.push([record, status])
          else
            nested_reflection_names_to_record_statuses[reflection_name] = [record, status]
          end
        end

        def on_nested_association(association)
          # Register the reflection as a key. Downstream code may need the information of whether an association has
          # been touched.
          record_statuses_for_nested_reflection_name(association.reflection.name)
        end

        def on_nested_record(association, record, status)
          register_record_status_for_nested_reflection(association.reflection.name, record, status)
        end

        def reload(options = nil)
          result = super

          # Clear the tracking state.
          nested_reflection_names_to_record_statuses.clear

          result
        end
      end
    end
  end
end
