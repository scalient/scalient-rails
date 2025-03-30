# frozen_string_literal: true

# Copyright 2025 Roy Liu
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
    module PreloaderBranchMonkeyPatch
      SPECIAL_LITERAL_SYNTAX_PATTERN = Regexp.new("\\A(?<prefix>[\\.:])(?<name>.*)\\z")

      def self.apply(clazz)
        outer_self = self

        clazz.class_eval do
          prepend outer_self
        end
      end

      def selects
        @selects ||= []
      end

      def polymorphic_specializations_to_subtrees
        @polymorphic_specializations_to_subtrees ||= {}
      end

      def polymorphic_specializations_to_subtrees=(polymorphic_specializations_to_subtrees)
        @polymorphic_specializations_to_subtrees = polymorphic_specializations_to_subtrees
      end

      # Overridden to preprocess special preload syntax and store those directives in auxiliary data structures, while
      # passing the normal syntax to the superclass method. Appends polymorphic specialization subtrees to the result so
      # that loading can proceed conditionally based on detected foreign types.
      def build_children(preloads)
        preloads = preloads.deep_dup

        if preloads
          preprocess_preloads!(preloads)
        end

        # Add the polymorphic specialization subtrees for consideration when later code interrogates subtrees for their
        # loaders.
        super + polymorphic_specializations_to_subtrees.values
      end

      # Preprocess the preload specification by populating auxiliary data structures and stripping out syntax that would
      # otherwise cause the regular preloader to choke.
      def preprocess_preloads!(preloads)
        case preloads
        when Hash
          preloads.select! do |reflection_name, sub_preloads|
            preprocess_literal(reflection_name, sub_preloads)
          end

          preloads.size > 0
        when Array
          preloads.select! do |sub_preloads|
            preprocess_preloads!(sub_preloads)
          end

          preloads.size > 0
        when String, Symbol
          preprocess_literal(preloads)
        else
          raise ArgumentError, "Invalid preload specification"
        end
      end

      # Preprocess a literal that is usually a reflection name, but sometimes is `.#{attribute_name}` or
      # `:#{class_name}`.
      def preprocess_literal(literal, preloads = nil)
        literal = literal.to_s

        if (m = SPECIAL_LITERAL_SYNTAX_PATTERN.match(literal))
          case m[:prefix]
          when "."
            # A `.#{attribute_name}` literal has been detected: This means that we want to selectively load the column
            # `attribute_name` in the parent relation's projection.
            selects.push(m[:name])
          when ":"
            name = m[:name]
            specialization_class = name.safe_constantize

            if !specialization_class
              raise ArgumentError, "No constant for class name #{name.dump} found"
            end

            # A `:#{class_name}` literal has been detected: This means that said preloads are for the specialized type
            # `class_name` under polymorphism. In effect, we disambiguate the nested reflections and attributes of the
            # single, overloaded polymorphic reflection in Rails' implementation with potentially different nested
            # reflections and attributes for each specialized type.
            polymorphic_specializations_to_subtrees[name] = self.class.new(
              parent:,
              association:,
              children: preloads,
              associate_by_default:,
              scope:,
            ).tap do |child|
              # Share the original map with specialized children.
              child.polymorphic_specializations_to_subtrees = polymorphic_specializations_to_subtrees
            end
          else
            raise "Control should never reach here"
          end

          # Signal to the caller to reject the item: We already gave it special treatment.
          false
        else
          # Signal to the caller to keep the item.
          true
        end
      end

      # Overridden to inject the columns referenced in `#selects` into the query scope's projection.
      #
      # TODO: The library currently doesn't automatically include primary keys and association foreign keys when using
      # dot syntax for selective preloading; those are the user's responsibility for now.
      def preloaders_for_reflection(reflection, reflection_records)
        reflection_records.group_by do |record|
          klass = record.association(association).klass

          if reflection.scope && reflection.scope.arity != 0
            # For instance dependent scopes, the scope is potentially
            # different for each record. To allow this we'll group each
            # object separately into its own preloader
            reflection_scope = reflection.join_scopes(
              klass.arel_table, klass.predicate_builder, klass, record,
            ).inject(&:merge!)
          end

          [klass, reflection_scope]
        end.map do |(rhs_klass, reflection_scope), rs|
          # Start off with the preloader's scope.
          preloader_scope = rhs_klass.select(selects)

          # Merge in the explicitly provided scope.
          if scope
            preloader_scope.merge!(scope)
          end

          preloader_for(reflection).new(
            rhs_klass, rs, reflection, preloader_scope, reflection_scope, associate_by_default,
          )
        end
      end

      # Overridden to consult polymorphic specialization subtrees if they are present in composite hash keys.
      def loaders
        # Try to destructure subtrees corresponding to polymorphic specializations.
        @loaders ||=
          grouped_records.flat_map do |(reflection, subtree), reflection_records|
            (!subtree ? self : subtree).preloaders_for_reflection(reflection, reflection_records)
          end
      end

      # Overridden to match records with potential polymorphic specializations.
      def grouped_records
        h = {}
        polymorphic_parent = !root? && parent.polymorphic?
        source_records.each do |record|
          reflection = record.class._reflect_on_association(association)
          next if (polymorphic_parent && !reflection) || !record.association(association).klass

          # If the reflection is a registered polymorphic specialization, include subtree information by setting a
          # composite hash key.
          key = if reflection.polymorphic? && polymorphic_specializations_to_subtrees.size > 0
            subtree = polymorphic_specializations_to_subtrees[record.read_attribute(reflection.foreign_type)]

            if self == subtree
              [reflection, subtree]
            else
              next
            end
          else
            reflection
          end

          (h[key] ||= []) << record
        end
        h
      end
    end
  end
end
