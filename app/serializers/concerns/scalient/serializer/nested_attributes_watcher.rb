# frozen_string_literal: true

# Copyright 2020-2024 Scalient LLC
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
        if !include?(::Scalient::ActiveRecord::NestedAttributesCapturing)
          send(:include, ::Scalient::ActiveRecord::NestedAttributesCapturing)
        end

        send(:prepend, InstanceMethods)
      end

      # This module now fronts for `Scalient::ActiveRecord::NestedAttributesCapturing`, which now provides its core
      # functionality.
      module InstanceMethods
        def nested_association_was_updated?(name)
          nested_reflection_names_to_record_statuses.key?(name)
        end

        def has_updated_nested_associations?
          nested_reflection_names_to_record_statuses.size > 0
        end
      end
    end
  end
end
