# frozen_string_literal: true
#
# Portions Copyright 2020 The Affective Computing Company
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
#
# Portions Copyright (c) 2004-2020 David Heinemeier Hansson
#
# Arel originally copyright (c) 2007-2016 Nick Kallen, Bryan Helmkamp, Emilio Tagua, Aaron Patterson
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

module ActiveRecord
  module Associations
    # A reimagining of `ActiveRecord::Associations::AssociationScope` to optionally allow for scoping on reflections as
    # well as queries to be run in reverse (`TheModel` joining to `Thing` instead of `Thing` joining to `TheModel` for
    # the `TheModel#things` association).
    class ReflectionScope < AssociationScope
      # Lifted from `ActiveRecord::Associations::AssociationScope.scope`.
      def self.scope(association, reversed = false)
        INSTANCE.scope(association, reversed)
      end

      # Lifted from `ActiveRecord::Associations::AssociationScope.create`.
      def self.create(&block)
        block ||= lambda { |val| val }
        new(block)
      end

      INSTANCE = create

      # Overwrites `ActiveRecord::Associations::AssociationScope#scope` to take reflections as arguments and the
      # `reversed` option.
      def scope(association_or_reflection, reversed = false)
        case association_or_reflection
        when Association
          association = association_or_reflection
          reflection = association_or_reflection.reflection
          owner = association_or_reflection.owner
        when ::ActiveRecord::Reflection::AbstractReflection
          association = nil
          reflection = association_or_reflection
          owner = nil
        else
          raise ArgumentError, "Please provide an association or reflection"
        end

        if !reversed
          klass = reflection.klass
        else
          # In a reversal, the starting point is the reflection's model.
          klass = reflection.active_record
        end

        scope = klass.unscoped
        chain = get_chain(reflection, association, scope.alias_tracker)

        scope.extending! reflection.extensions
        scope = add_constraints(scope, owner, chain, reversed)
        scope.limit!(1) unless reflection.collection?
        scope
      end

      # Overwrites `ActiveRecord::Associations::AssociationScope#last_chain_scope` to support the `reversed` option.
      def last_chain_scope(scope, reflection, owner, reversed)
        reflection_owner_class = reflection.active_record

        if !reversed
          key = reflection.join_primary_key
          foreign_key = reflection.join_foreign_key
          table = reflection.aliased_table
          foreign_table = reflection_owner_class.arel_table
          constraint = table[key].eq(foreign_table[foreign_key])

          if owner
            value = transform_value(owner[foreign_key])

            scope = apply_scope(scope, table, key, value)

            if reflection.type
              polymorphic_type = transform_value(owner.class.polymorphic_name)
              scope = apply_scope(scope, table, reflection.type, polymorphic_type)
            end
          else
            scope.joins!(join(foreign_table, constraint))

            if reflection.type
              polymorphic_type = transform_value(reflection_owner_class.polymorphic_name)
              scope = apply_scope(scope, table, reflection.type, polymorphic_type)
            end
          end
        else
          # In a reversal, foreign and primary keys are transposed.
          key = reflection.join_foreign_key
          foreign_key = reflection.join_primary_key
          table = scope.arel_table
          foreign_table = reflection.aliased_table
          constraint = table[key].eq(foreign_table[foreign_key])

          if owner
            value = transform_value(owner[key])

            scope = apply_scope(scope, table, key, value)

            if reflection.type
              polymorphic_type = transform_value(owner.class.polymorphic_name)
              scope = apply_scope(scope, foreign_table, reflection.type, polymorphic_type)
            end
          else
            if reflection.type
              polymorphic_type = transform_value(reflection_owner_class.polymorphic_name)
              scope = apply_scope(scope, foreign_table, reflection.type, polymorphic_type)
            end
          end

          scope.joins!(join(foreign_table, constraint))
        end

        scope
      end

      # Overwrites `ActiveRecord::Associations::AssociationScope#next_chain_scope` to support the `reversed` option.
      def next_chain_scope(scope, reflection, next_reflection, reversed)
        table = reflection.aliased_table
        foreign_table = next_reflection.aliased_table

        if !reversed
          key = reflection.join_primary_key
          foreign_key = reflection.join_foreign_key
          constraint = table[key].eq(foreign_table[foreign_key])

          if reflection.type
            value = transform_value(next_reflection.klass.polymorphic_name)
            scope = apply_scope(scope, table, reflection.type, value)
          end
        else
          # In a reversal, foreign and primary keys are transposed and we consult the next reflection for join
          # information.
          key = next_reflection.join_foreign_key
          foreign_key = next_reflection.join_primary_key
          constraint = table[key].eq(foreign_table[foreign_key])

          if next_reflection.type
            value = transform_value(reflection.klass.polymorphic_name)
            scope = apply_scope(scope, foreign_table, next_reflection.type, value)
          end
        end

        scope.joins!(join(foreign_table, constraint))
      end

      # Overwrites `ActiveRecord::Reflection::RuntimeReflection` to expose the `active_record` accessor.
      class RuntimeReflection < ::ActiveRecord::Reflection::RuntimeReflection
        delegate :active_record, to: :@reflection
      end

      # Overwrites `ActiveRecord::Associations::AssociationScope#get_chain` to take reflections as arguments.
      def get_chain(reflection, association, tracker)
        name = reflection.name
        chain = [RuntimeReflection.new(reflection, association || reflection)]
        reflection.chain.drop(1).each do |refl|
          aliased_table = tracker.aliased_table_for(refl.klass.arel_table) do
            refl.alias_candidate(name)
          end
          chain << ReflectionProxy.new(refl, aliased_table)
        end
        chain
      end

      # Overwrites `ActiveRecord::Associations::AssociationScope#add_constraints` to support the `reversed` option.
      def add_constraints(scope, owner, chain, reversed)
        if !reversed
          chain.each_cons(2) do |reflection, next_reflection|
            scope = next_chain_scope(scope, reflection, next_reflection, reversed)
          end

          scope = last_chain_scope(scope, chain.last, owner, reversed)
        else
          scope = last_chain_scope(scope, chain.last, owner, reversed)

          chain.reverse.each_cons(2) do |reflection, next_reflection|
            scope = next_chain_scope(scope, reflection, next_reflection, reversed)
          end
        end

        chain_head = chain.first
        chain.reverse_each do |reflection|
          # Exclude the scope of the association itself, because that
          # was already merged in the #scope method.
          reflection.constraints.each do |scope_chain_item|
            item = eval_scope(reflection, scope_chain_item, owner)

            if scope_chain_item == chain_head.scope
              scope.merge! item.except(:where, :includes, :unscope, :order)
            end

            reflection.all_includes do
              scope.includes! item.includes_values
            end

            scope.unscope!(*item.unscope_values)
            scope.where_clause += item.where_clause
            scope.order_values = item.order_values | scope.order_values
          end
        end

        scope
      end
    end
  end
end
