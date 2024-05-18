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

      ALLOWED_CREATE_INVERSE_OPTIONS = [:after, :foreign_key, :multiplicity, :scope, :source, :through].freeze

      included do
        raise ArgumentError, "This concern should be prepended"
      end

      module ClassMethods
        def belongs_to(association_name, scope = nil, **options)
          create_inverse_options = options.delete(:create_inverse)

          if !create_inverse_options
            super
          else
            create_inverse_options = normalize_create_inverse_options(create_inverse_options)
            create_inverse_options => {
              create_inverse_scope:,
              create_inverse_multiplicity:,
              create_inverse_after_hook:
            }

            inverse_name = add_explicit_inverse_of_option!(:belongs_to, create_inverse_options, options)

            reflections = super

            new_reflection = reflections[association_name.to_s]

            class_name = options[:class_name] || new_reflection.name.to_s.camelize
            target_class = class_name.safe_constantize

            if !target_class
              raise ArgumentError, "Target class #{class_name.dump} not found"
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

            reflections
          end
        end

        def has_many(association_name, scope = nil, **options)
          create_inverse_options = options.delete(:create_inverse)

          if !create_inverse_options
            super
          else
            create_inverse_options = normalize_create_inverse_options(create_inverse_options)
            add_explicit_inverse_of_option!(:has, create_inverse_options, options)

            reflections = super

            create_has_inverse(reflections[association_name.to_s], create_inverse_options, **options)

            reflections
          end
        end

        def has_one(association_name, scope = nil, **options)
          create_inverse_options = options.delete(:create_inverse)

          if !create_inverse_options
            super
          else
            create_inverse_options = normalize_create_inverse_options(create_inverse_options)
            add_explicit_inverse_of_option!(:has, create_inverse_options, options)

            reflections = super

            create_has_inverse(reflections[association_name.to_s], create_inverse_options, **options)

            reflections
          end
        end

        def create_has_inverse(new_reflection, create_inverse_options, **options)
          create_inverse_options => {
            create_inverse_scope:,
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
          # This is guaranteed to exist, and as a string too.
          inverse_name = options[:inverse_of]

          target_options = {}

          if !through_reflection
            polymorphic_belongs_to_name = options[:as]&.to_s

            if target_class.reflections[inverse_name]
              raise "Target class already has inverse association #{inverse_name.dump}"
            end

            foreign_key = if create_inverse_options.include?(:create_inverse_foreign_key)
              create_inverse_options[:create_inverse_foreign_key]
            else
              new_reflection.foreign_key
            end

            if foreign_key
              target_options.merge!(
                # The foreign key that was determined by `super`.
                foreign_key:,
              )
            end

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
            if (foreign_key = create_inverse_options[:create_inverse_foreign_key])
              target_options.merge!(foreign_key:)
            end

            if target_class.reflections[inverse_name]
              raise "Target class already has inverse association #{inverse_name.dump}"
            end

            through_name = if create_inverse_options.include?(:create_inverse_through)
              create_inverse_options[:create_inverse_through]
            else
              through_reflection.name
            end

            if !through_reflection.is_a?(::ActiveRecord::Reflection::BelongsToReflection)
              source_reflection = through_reflection.inverse_of

              # The source reflection on the created inverse association is the inverse of the through reflection as it
              # appears from the perspective of the current association.
              if !source_reflection
                raise ArgumentError, "No inverse detected on through association " \
                  "#{through_reflection.name.to_s.dump}. This is needed to identify `source` on the generated " \
                  "`create_inverse` association"
              end

              source_name = if create_inverse_options.include?(:create_inverse_source)
                create_inverse_options[:create_inverse_source]
              else
                source_reflection.name
              end

              if through_name
                target_options.merge!(
                  # The through association in the reverse direction.
                  through: through_name,
                )
              end

              if source_name
                target_options.merge!(
                  # Helps traverse the through association.
                  source: source_name,
                )
              end

              # Is the source reflection polymorphic? We need to add `source_type` for disambiguation purposes.
              if !source_reflection.polymorphic?
                # No-op.
              else
                target_options.merge!(
                  # Just the name of the current class.
                  source_type: name,
                )
              end
            else
              if (through_name = create_inverse_options[:create_inverse_through])
                target_options.merge!(
                  # The through association in the reverse direction.
                  through: through_name,
                )
              end

              if (source_name = create_inverse_options[:create_inverse_source])
                target_options.merge!(
                  # The source association in the reverse direction.
                  source: source_name,
                )
              end
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
          create_inverse_multiplicity = :many
          create_inverse_after_hook = -> {}

          normalized_options = {}

          if create_inverse_options.is_a?(Hash)
            invalid_options = (create_inverse_options.keys - ALLOWED_CREATE_INVERSE_OPTIONS)

            if invalid_options.size > 0
              raise ArgumentError,
                    "Invalid `create_inverse` options #{invalid_options.map(&:to_s).map(&:dump).join(", ")}"
            end

            create_inverse_scope = create_inverse_options[:scope]
            create_inverse_multiplicity = (create_inverse_options[:multiplicity] || create_inverse_multiplicity).to_sym
            create_inverse_after_hook = create_inverse_options[:after] || create_inverse_after_hook

            case create_inverse_multiplicity
            when :many, :one
            else
              raise ArgumentError, "Invalid `create_inverse` multiplicity #{create_inverse_multiplicity.to_s.dump}"
            end

            [:foreign_key, :through, :source].each do |key|
              if create_inverse_options.include?(key)
                normalized_options[:"create_inverse_#{key}"] = create_inverse_options[key]
              end
            end
          end

          normalized_options.merge!(
            create_inverse_scope:,
            create_inverse_multiplicity:,
            create_inverse_after_hook:,
          )

          normalized_options
        end

        def add_explicit_inverse_of_option!(association_type, create_inverse_options, options)
          create_inverse_options => {
            create_inverse_multiplicity:
          }

          through_reflection = reflections[options[:through]&.to_s]
          inverse_of_name = options[:inverse_of]&.to_s
          inverse_name = if !through_reflection && association_type == :has
            inverse_of_name || model_name.singular
          else
            inverse_of_name ||
              case create_inverse_multiplicity
              when :many
                model_name.plural
              when :one
                model_name.singular
              else
                raise "Control should never reach here"
              end
          end

          # Be helpful and add an explicit inverse if one hasn't been declared. If it already exists, then effectively
          # this normalizes the value to a string.
          options.merge!(inverse_of: inverse_name)

          inverse_name
        end
      end
    end
  end
end
