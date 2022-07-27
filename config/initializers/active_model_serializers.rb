# frozen_string_literal: true

#
# Copyright 2019-2021 The Affective Computing Company
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

ActiveModelSerializers.config.tap do |config|
  config.adapter = :json_api
  config.jsonapi_use_foreign_key_on_belongs_to_relationship = true

  # This is very similar to `BY_RESOURCE_NAMESPACE`, except it also takes into account the explicitly provided
  # namespace.
  by_resource_namespace_and_explicit_namespace = proc do |resource_class, _serializer_class, _namespace|
    resource_namespace = ActiveModelSerializers::LookupChain.namespace_for(resource_class)
    serializer_name = ActiveModelSerializers::LookupChain.serializer_from(resource_class)

    "#{_namespace ? "#{_namespace}::" : ""}#{resource_namespace}::#{serializer_name}"
  end

  config.serializer_lookup_chain = [
    by_resource_namespace_and_explicit_namespace,
    ActiveModelSerializers::LookupChain::BY_PARENT_SERIALIZER,
    ActiveModelSerializers::LookupChain::BY_NAMESPACE,
    ActiveModelSerializers::LookupChain::BY_RESOURCE_NAMESPACE
    # We deliberately leave this one out to prevent surprising behavior. In other words, `MyModule::MyModel` will never
    # match `MyModelSerializer`.
    # ActiveModelSerializers::LookupChain::BY_RESOURCE,
  ]
end

require "active_model_serializers/adapter/json_api/resource_identifier"
require "active_model_serializers/adapter/json_api/relationship"

module ActiveModelSerializers
  module Adapter
    class JsonApi < Base
      # Monkey patch this to properly dasherize polymorphic association types (see
      # `https://github.com/rails-api/active_model_serializers/blob/8f38571/lib/active_model_serializers/adapter/json_api/resource_identifier.rb#L7-L10`
      # ).
      class ResourceIdentifier
        def self.type_for(serializer, serializer_type = nil, transform_options = {})
          if serializer_type
            raw_type = inflect_type(serializer_type)
            raw_type.gsub!("/", ActiveModelSerializers.config.jsonapi_namespace_separator)
          else
            raw_type = raw_type_from_serializer_object(serializer.object)
          end

          ::ActiveModelSerializers::Adapter::JsonApi.send(:transform_key_casing!, raw_type, transform_options)
        end
      end

      # Monkey patch this so that if the polymorphic association's serializer couldn't be found, conservatively return
      # `nil` (see
      # `https://github.com/rails-api/active_model_serializers/blob/8f38571/lib/active_model_serializers/adapter/json_api/relationship.rb#L54``
      # ).
      class Relationship
        def data_for_one(association)
          if belongs_to_id_on_self?(association)
            id = parent_serializer.read_attribute_for_serialization(association.reflection.foreign_key)
            type =
              if association.polymorphic?
                # We can't infer resource type for polymorphic relationships from the serializer.
                # We can ONLY know a polymorphic resource type by inspecting each resource.
                association.lazy_association.serializer&.json_key
              else
                association.reflection.type.to_s
              end

            # A `nil` type implies `null` data.
            if type
              ResourceIdentifier.for_type_with_id(type, id, serializable_resource_options)
            else
              nil
            end
          else
            # TODO(BF): Process relationship without evaluating lazy_association
            serializer = association.lazy_association.serializer
            if (virtual_value = association.virtual_value)
              virtual_value
            elsif serializer && association.object
              ResourceIdentifier.new(serializer, serializable_resource_options).as_json
            else
              nil
            end
          end
        end
      end
    end
  end
end
