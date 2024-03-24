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
        send(:extend, ClassMethods)
      end

      def serialize_reluctant_association?(name)
        object.association(name).loaded? ||
          (is_update_action? && !!object.try(:nested_association_was_updated?, name))
      end

      def is_update_action?
        instance_eval(&self.class.update_action_predicate)
      end

      module ClassMethods
        def self.extended(klass)
          klass.class_eval do
            class_attribute :_update_action_predicate
            class_attribute :_include_belongs_to_foreign_key
            class_attribute :_foreign_type_inflection
          end
        end

        def update_action_predicate(&block)
          if !block
            self._update_action_predicate ||= proc do
              template = instance_options[:template]
              ["update", "create"].include?(template)
            end
          else
            self._update_action_predicate = block
          end
        end

        def include_belongs_to_foreign_key(value = nil)
          case value
          when nil
            self._include_belongs_to_foreign_key ||= :reluctant
          when :always, :reluctant, :never
            self._include_belongs_to_foreign_key = value
          else
            raise ArgumentError, "Value should be one of `always`, `reluctant`, `never`"
          end
        end

        def foreign_type_inflection(&block)
          if !block
            self._foreign_type_inflection ||= proc do |type|
              type.underscore.pluralize
            end
          else
            self._foreign_type_inflection = block
          end
        end

        def has_many_reluctant(name, *args)
          name = name.to_sym

          has_many name, *args, if: (-> do
            serialize_reluctant_association?(name)
          end)

          define_method(name) do
            # The association has supposedly been loaded into the `target` for non-update-like actions, and recently
            # created or updated records show up here for update-like actions.
            object.association(name).target
          end
        end

        def has_one_reluctant(name, *args)
          name = name.to_sym

          has_one name, *args, if: (-> do
            serialize_reluctant_association?(name)
          end)
        end

        def belongs_to_reluctant(name, *args)
          options = args.extract_options!

          name = name.to_sym
          belongs_to_reflection = nil

          # Allow explicit specification of the reference class name.
          if (class_name = options[:class_name]) &&
              (model_class = class_name.safe_constantize) &&
              (reflection = model_class.reflections[name.to_s]) &&
              reflection.is_a?(::ActiveRecord::Reflection::BelongsToReflection)
            belongs_to_reflection = reflection
          end

          # Try to infer the reference class name from the serializer class name.
          if !belongs_to_reflection &&
              (m = SERIALIZER_NAME_PATTERN.match(self.name)) &&
              (model_class = m[:class_name].safe_constantize) &&
              (reflection = model_class.reflections[name.to_s]) &&
              reflection.is_a?(::ActiveRecord::Reflection::BelongsToReflection)
            belongs_to_reflection = reflection
          end

          if belongs_to_reflection
            foreign_key = belongs_to_reflection.foreign_key
            foreign_type = belongs_to_reflection.foreign_type

            [foreign_key, foreign_type].compact.each do |fk_attribute|
              attribute fk_attribute, if: (-> do
                # Write foreign keys only if the full association isn't being serialized.
                case self.class.include_belongs_to_foreign_key
                when :reluctant
                  !serialize_reluctant_association?(name)
                when :always
                  true
                else
                  false
                end
              end)
            end

            # Make sure the foreign key is a string (or `nil`) per the JSON:API specification.
            define_method(foreign_key) do
              object.send(foreign_key)&.to_s
            end

            if foreign_type
              define_method(foreign_type) do
                type = object.send(foreign_type)
                serializer = self.class.serializer_for(type&.safe_constantize, namespace: instance_options[:namespace])
                serializer&._type || (type && self.class.foreign_type_inflection.call(type))
              end
            end
          end

          belongs_to name, options.merge(
            if: (-> do
              serialize_reluctant_association?(name)
            end)
          )
        end
      end
    end
  end
end
