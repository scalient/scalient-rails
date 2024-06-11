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
    module NestedAttributesCallbacks
      extend ActiveSupport::Concern

      included do
        if is_a?(::ActionController::Base)
          raise ArgumentError, "Please mix this into a controller"
        end

        send(:prepend, InstanceMethods)
      end

      module InstanceMethods
        UNASSIGNABLE_KEYS = ["id", "_destroy"].freeze

        # Copied from the Rails source code except for the commented line.
        def assign_nested_attributes_for_one_to_one_association(association_name, attributes)
          options = nested_attributes_options[association_name]
          if attributes.respond_to?(:permitted?)
            attributes = attributes.to_h
          end
          attributes = attributes.with_indifferent_access
          existing_record = send(association_name)

          # Our modifications: Pull the association into a higher lexical scope.
          association = association(association_name)

          # Our modifications: Invoke a callback here.
          on_nested_association(association)

          if (options[:update_only] || !attributes["id"].blank?) && existing_record &&
              (options[:update_only] || existing_record.id.to_s == attributes["id"].to_s)
            unless call_reject_if(association_name, attributes)
              assign_to_or_mark_for_destruction(existing_record, attributes, options[:allow_destroy])

              # Our modifications: Invoke a callback here.
              on_nested_record(
                association, existing_record, !existing_record.marked_for_destruction? ? :update : :destroy,
              )
            end
          elsif attributes["id"].present?
            raise_nested_attributes_record_not_found!(association_name, attributes["id"])
          elsif !reject_new_record?(association_name, attributes)
            assignable_attributes = attributes.except(*UNASSIGNABLE_KEYS)

            if existing_record&.new_record?
              existing_record.assign_attributes(assignable_attributes)
              association.initialize_attributes(existing_record)
            else
              method = :"build_#{association_name}"
              if respond_to?(method)
                new_record = send(method, assignable_attributes)

                # Our modifications: Invoke a callback here.
                on_nested_record(association, new_record, :create)
              else
                raise ArgumentError, "Cannot build association `#{association_name}'. Are you trying to build a " \
                  "polymorphic one-to-one association?"
              end
            end
          end
        end

        # Copied from the Rails source code except for the commented line.
        def assign_nested_attributes_for_collection_association(association_name, attributes_collection)
          options = nested_attributes_options[association_name]
          if attributes_collection.respond_to?(:permitted?)
            attributes_collection = attributes_collection.to_h
          end

          unless attributes_collection.is_a?(Hash) || attributes_collection.is_a?(Array)
            raise ArgumentError, "Hash or Array expected for attribute `#{association_name}`, got " \
              "#{attributes_collection.class.name} (#{attributes_collection.inspect})"
          end

          check_record_limit!(options[:limit], attributes_collection)

          if attributes_collection.is_a? Hash
            keys = attributes_collection.keys
            attributes_collection = if keys.include?("id") || keys.include?(:id)
              [attributes_collection]
            else
              attributes_collection.values
            end
          end

          association = association(association_name)

          # Our modifications: Invoke a callback here.
          on_nested_association(association)

          existing_records = if association.loaded?
            association.target
          else
            attribute_ids = attributes_collection.filter_map { |a| a["id"] || a[:id] }
            attribute_ids.empty? ? [] : association.scope.where(association.klass.primary_key => attribute_ids)
          end

          attributes_collection.each do |attributes|
            if attributes.respond_to?(:permitted?)
              attributes = attributes.to_h
            end
            attributes = attributes.with_indifferent_access

            if attributes["id"].blank?
              unless reject_new_record?(association_name, attributes)
                new_record = association.reader.build(attributes.except(*UNASSIGNABLE_KEYS))

                # Our modifications: Invoke a callback here.
                on_nested_record(association, new_record, :create)
              end
            elsif (existing_record = existing_records.detect { |record| record.id.to_s == attributes["id"].to_s })
              unless call_reject_if(association_name, attributes)
                # Make sure we are operating on the actual object which is in the association's
                # proxy_target array (either by finding it, or adding it if not found)
                # Take into account that the proxy_target may have changed due to callbacks
                target_record = association.target.detect { |record| record.id.to_s == attributes["id"].to_s }
                if target_record
                  existing_record = target_record
                else
                  association.add_to_target(existing_record, skip_callbacks: true)
                end

                assign_to_or_mark_for_destruction(existing_record, attributes, options[:allow_destroy])

                # Our modifications: Invoke a callback here.
                on_nested_record(
                  association, existing_record, !existing_record.marked_for_destruction? ? :update : :destroy,
                )
              end
            else
              raise_nested_attributes_record_not_found!(association_name, attributes["id"])
            end
          end
        end

        # To be implemented by downstream.
        def on_nested_association(association)
        end

        # To be implemented by downstream.
        def on_nested_record(association, record, status)
        end
      end
    end
  end
end
