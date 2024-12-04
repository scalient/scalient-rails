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
    module EagerLoadRewriting
      extend ActiveSupport::Concern

      LITERAL_PATTERN = Regexp.new(
        "\\A(?<reflection_name>[A-Za-z_][A-Za-z0-9_]*)?" \
          "(\\.(?<column_name>[A-Za-z_][A-Za-z0-9_]*))?\\z",
      )

      module ClassMethods
        def rewrite_selects_and_eager_loads(selects, eager_loads)
          rewritten_selects, rewritten_eager_loads = _rewrite_selects_and_eager_loads(selects, eager_loads)

          selects.find do |potential_column_name|
            if column_names.include?(potential_column_name.to_s)
              # We're selectively projecting root table columns: Prepend the magical `:_brick_eager_load` to trigger
              # the brick gem's special eager loading behavior.
              rewritten_selects.unshift(:_brick_eager_load).uniq!
            end
          end

          rewritten_selects.concat(selects.map(&:to_s))

          [rewritten_selects, rewritten_eager_loads]
        end

        def _rewrite_selects_and_eager_loads(
          selects, eager_loads, parent_reflection_name = nil, rewritten_selects = [], rewritten_eager_loads = {}
        )
          case eager_loads
          when Hash
            eager_loads.each_entry do |reflection_name, sub_eager_loads|
              reflection_name = reflection_name.to_s

              m = LITERAL_PATTERN.match(reflection_name)

              if !m[:column_name]
                _rewrite_selects_and_eager_loads(
                  selects, sub_eager_loads, reflection_name, rewritten_selects,
                  rewritten_eager_loads[reflection_name] = {},
                )
              else
                rewrite_association_name(
                  parent_reflection_name, reflection_name, rewritten_selects, rewritten_eager_loads,
                )
              end
            end
          when Array
            eager_loads.each do |sub_eager_loads|
              _rewrite_selects_and_eager_loads(
                selects, sub_eager_loads, parent_reflection_name, rewritten_selects, rewritten_eager_loads,
              )
            end
          when String, Symbol
            rewrite_association_name(parent_reflection_name, eager_loads, rewritten_selects, rewritten_eager_loads)
          end

          [rewritten_selects, rewritten_eager_loads]
        end

        def rewrite_association_name(parent_reflection_name, literal, rewritten_selects, rewritten_eager_loads)
          literal = literal.to_s

          m = LITERAL_PATTERN.match(literal)

          if !m
            raise ArgumentError, "Invalid brick-extended eager load literal #{literal.dump}"
          end

          reflection_name = m[:reflection_name]
          column_name = m[:column_name]

          if reflection_name
            sub_rewritten_eager_loads = {}
            rewritten_eager_loads[reflection_name] = sub_rewritten_eager_loads

            if column_name
              rewrite_association_name(reflection_name, ".#{column_name}", rewritten_selects, sub_rewritten_eager_loads)
            end
          else
            if column_name
              rewritten_selects.push(if parent_reflection_name
                # We actually use the parent reflection to look up its source reflection, whose name is being used in
                # the query.
                "#{reflections[parent_reflection_name].source_reflection.name}.#{column_name}"
              else
                column_name
              end)

              # We're selectively projecting reflection table columns: Prepend the magical `:_brick_eager_load` to
              # trigger the brick gem's special eager loading behavior.
              rewritten_selects.unshift(:_brick_eager_load).uniq!
            end
          end
        end
      end
    end
  end
end
