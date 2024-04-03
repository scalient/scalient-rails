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
    module AssociationInversing
      extend ActiveSupport::Concern

      ALLOWED_CREATE_INVERSE_OPTIONS = [:after, :multiplicity, :scope, :source, :through].freeze

      included do
        raise ArgumentError, "This concern should be prepended"
      end

      module ClassMethods
        def belongs_to(association_name, scope = nil, **options)
          create_inverse_options = options.delete(:create_inverse)

          reflections = super

          if create_inverse_options
            new_reflection = reflections[association_name.to_s]

            normalize_create_inverse_options(create_inverse_options) => {
              create_inverse_scope:,
              create_inverse_multiplicity:,
              create_inverse_after_hook:
            }

            class_name = options[:class_name] || new_reflection.name.to_s.camelize
            target_class = class_name.safe_constantize

            if !target_class
              raise ArgumentError, "Target class #{class_name.dump} not found"
            end

            inverse_of_name = options[:inverse_of]&.to_s
            inverse_name = inverse_of_name ||
              case create_inverse_multiplicity
              when :many
                model_name.plural
              when :one
                model_name.singular
              else
                raise "Control should never reach here"
              end

            is_polymorphic = !!options[:polymorphic] || false

            if target_class.reflections[inverse_name]
              raise "Target class already has inverse association #{inverse_name.dump}"
            end

            target_options = {
              # Just the name of the current association.
              inverse_of: new_reflection.name,
              # Just the name of the current class.
              class_name: name,
              # The foreign key that was determined by `super`.
              foreign_key: new_reflection.foreign_key,
            }

            if !is_polymorphic
              target_options.merge!(
                # The primary key that was determine by `super`.
                primary_key: new_reflection.association_primary_key,
              )
            else
              raise ArgumentError, "Inverse creation against a polymorphic `belongs_to` association is not allowed " \
                "because it is inherently ambiguous"
            end

            case create_inverse_multiplicity
            when :many
              target_class.has_many inverse_name.to_sym, create_inverse_scope, **target_options
            when :one
              target_class.has_one inverse_name.to_sym, create_inverse_scope, **target_options
            else
              raise "Control should never reach here"
            end

            target_class.instance_exec(&create_inverse_after_hook)
          end

          reflections
        end

        def has_many(association_name, scope = nil, **options)
          create_inverse_options = options.delete(:create_inverse)

          reflections = super

          if create_inverse_options
            create_has_inverse(reflections[association_name.to_s], create_inverse_options, **options)
          end

          reflections
        end

        def has_one(association_name, scope = nil, **options)
          create_inverse_options = options.delete(:create_inverse)

          reflections = super

          if create_inverse_options
            create_has_inverse(reflections[association_name.to_s], create_inverse_options, **options)
          end

          reflections
        end

        def create_has_inverse(new_reflection, create_inverse_options, **options)
          normalize_create_inverse_options(create_inverse_options) => {
            create_inverse_scope:,
            create_inverse_through_name:,
            create_inverse_source_name:,
            create_inverse_multiplicity:,
            create_inverse_after_hook:
          }

          class_name = options[:class_name] ||
            (new_reflection.collection? ? new_reflection.name.to_s.singularize : new_reflection.name.to_s).camelize
          target_class = class_name.safe_constantize

          if !target_class
            raise ArgumentError, "Target class #{class_name.dump} not found"
          end

          through_reflection = reflections[options[:through]&.to_s]
          inverse_of_name = options[:inverse_of]&.to_s

          target_options = {}

          if !through_reflection
            inverse_name = inverse_of_name || model_name.singular
            polymorphic_belongs_to_name = options[:as]&.to_s

            if target_class.reflections[inverse_name]
              raise "Target class already has inverse association #{inverse_name.dump}"
            end

            target_options.merge!(
              # The foreign key that was determined by `super`.
              foreign_key: new_reflection.foreign_key,
            )

            if !polymorphic_belongs_to_name
              target_options.merge!(
                # Just the name of the current association.
                inverse_of: new_reflection.name,
                # Just the name of the current class.
                class_name: name,
                # The primary key that was determine by `super`.
                primary_key: new_reflection.association_primary_key,
              )
            else
              # NOTE: `inverse_of`, `class_name`, and `primary_key` are indeterminate since the inverse is a polymorphic
              # `belongs_to`.
              target_options.merge!(
                # Since we detect `as`, this is polymorphic.
                polymorphic: true,
                # The foreign type that was determined by `super`.
                foreign_type: new_reflection.type,
              )
            end

            # The user will almost always intend for the inverse `belongs_to` to be optional, so check if it hasn't
            # been explicitly set.
            if !target_options.include?(:optional)
              target_options.merge!(
                optional: true,
              )
            end

            target_class.belongs_to inverse_name.to_sym, create_inverse_scope, **target_options
          else
            inverse_name = inverse_of_name ||
              case create_inverse_multiplicity
              when :many
                model_name.plural
              when :one
                model_name.singular
              else
                raise "Control should never reach here"
              end

            if target_class.reflections[inverse_name]
              raise "Target class already has inverse association #{inverse_name.dump}"
            end

            create_inverse_through_name ||= through_reflection.name

            if !through_reflection.is_a?(::ActiveRecord::Reflection::BelongsToReflection)
              create_inverse_source_reflection = through_reflection.inverse_of

              # The source reflection on the created inverse association is the inverse of the through reflection as it
              # appears from the perspective of the current association.
              if !create_inverse_source_reflection
                raise ArgumentError, "No inverse detected on through association " \
                  "#{through_reflection.name.to_s.dump}. This is needed to identify `source` on the generated " \
                  "`create_inverse` association"
              end

              target_options.merge!(
                # The through association in the reverse direction.
                through: create_inverse_through_name,
                # Helps traverse the through association.
                source: create_inverse_source_reflection.name,
              )

              # Is the source reflection polymorphic? We need to add `source_type` for disambiguation purposes.
              if !create_inverse_source_reflection.polymorphic?
                # No-op.
              else
                target_options.merge!(
                  # Just the name of the current class.
                  source_type: name,
                )
              end
            else
              target_options.merge!(
                # The through association in the reverse direction.
                through: create_inverse_through_name,
                # The source association in the reverse direction.
                source: create_inverse_source_name,
              )
            end

            case create_inverse_multiplicity
            when :many
              target_class.has_many inverse_name.to_sym, create_inverse_scope, **target_options
            when :one
              target_class.has_one inverse_name.to_sym, create_inverse_scope, **target_options
            else
              raise "Control should never reach here"
            end
          end

          target_class.instance_exec(&create_inverse_after_hook)

          new_reflection
        end

        def normalize_create_inverse_options(create_inverse_options)
          create_inverse_scope = nil
          create_inverse_through_name = nil
          create_inverse_source_name = nil
          create_inverse_multiplicity = :many
          create_inverse_after_hook = -> {}

          if create_inverse_options.is_a?(Hash)
            invalid_options = (create_inverse_options.keys - ALLOWED_CREATE_INVERSE_OPTIONS)

            if invalid_options.size > 0
              raise ArgumentError,
                    "Invalid `create_inverse` options #{invalid_options.map(&:to_s).map(&:dump).join(", ")}"
            end

            create_inverse_scope = create_inverse_options[:scope]
            create_inverse_through_name = create_inverse_options[:through]&.to_s
            create_inverse_source_name = create_inverse_options[:source]&.to_s
            create_inverse_multiplicity = (create_inverse_options[:multiplicity] || create_inverse_multiplicity).to_sym
            create_inverse_after_hook = create_inverse_options[:after] || create_inverse_after_hook

            case create_inverse_multiplicity
            when :many, :one
            else
              raise ArgumentError, "Invalid `create_inverse` multiplicity #{create_inverse_multiplicity.to_s.dump}"
            end
          end

          {
            create_inverse_scope:,
            create_inverse_through_name:,
            create_inverse_source_name:,
            create_inverse_multiplicity:,
            create_inverse_after_hook:,
          }
        end
      end
    end
  end
end
