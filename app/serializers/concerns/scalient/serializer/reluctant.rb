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
    module Reluctant
      extend ActiveSupport::Concern

      SERIALIZER_NAME_PATTERN = Regexp.new("\\A(?<class_name>.*)Serializer\\z")

      included do
        self.send(:extend, ClassMethods)
      end

      def serialize_reluctant_association?(name)
        if !is_update_action?
          object.association(name).loaded?
        else
          # Go through with serialization if nested updates are detected.
          !!object.try(:nested_association_was_updated?, name)
        end
      end

      def is_update_action?
        instance_eval(&self.class.update_action_predicate)
      end

      module ClassMethods
        def update_action_predicate(&block)
          @update_action_predicate = block || @update_action_predicate || Proc.new do
            instance_options[:template] == "update"
          end
        end

        def has_many_reluctant(name, *args)
          name = name.to_sym

          has_many name, *args, if: (lambda do
            serialize_reluctant_association?(name)
          end)

          define_method(name) do
            # The association has supposedly been loaded into the `target`.
            targets = object.association(name).target

            if !is_update_action?
              targets
            else
              targets.select do |target|
                # Does the nested object have nested updates, or does it itself have changes?
                !!target.try(:has_updated_nested_associations?) || target.previous_changes.size > 0
              end
            end
          end
        end

        def has_one_reluctant(name, *args)
          name = name.to_sym

          has_one name, *args, if: (lambda do
            serialize_reluctant_association?(name)
          end)
        end

        def belongs_to_reluctant(name, *args)
          options = args.extract_options!

          name = name.to_sym
          belongs_to_reflection = nil

          # Allow explicit specification of the reference class name.
          if (class_name = options.delete(:class_name)) &&
              (model_class = class_name.safe_constantize) &&
              (reflection = model_class.reflections[name.to_s]) &&
              reflection.is_a?(ActiveRecord::Reflection::BelongsToReflection)
            belongs_to_reflection = reflection
          end

          # Try to infer the reference class name from the serializer class name.
          if !belongs_to_reflection &&
              (m = SERIALIZER_NAME_PATTERN.match(self.name)) &&
              (model_class = m[:class_name].safe_constantize) &&
              (reflection = model_class.reflections[name.to_s]) &&
              reflection.is_a?(ActiveRecord::Reflection::BelongsToReflection)
            belongs_to_reflection = reflection
          end

          if belongs_to_reflection
            foreign_key = belongs_to_reflection.foreign_key
            foreign_type = belongs_to_reflection.foreign_type

            [foreign_key, foreign_type].compact.each do |fk_attribute|
              attribute fk_attribute, if: (lambda do
                # Write foreign keys only if the full association isn't being serialized.
                !serialize_reluctant_association?(name)
              end)
            end

            # Make sure the foreign key is a string per the JSON:API specification.
            define_method(foreign_key) do
              object.send(foreign_key).to_s
            end
          end

          belongs_to name, options.merge(
              if: (lambda do
                serialize_reluctant_association?(name)
              end)
          )
        end
      end
    end
  end
end
