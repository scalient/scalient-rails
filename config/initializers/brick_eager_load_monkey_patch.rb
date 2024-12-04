# frozen_string_literal: true

# Copyright (c) 2024 Lorin Thwaits (lorint@gmail.com)
#
# Released under the MIT licence.

module ActiveRecord
  module Associations
    class JoinDependency
      # An intelligent .eager_load() and .includes() that creates t0_r0 style aliases only for the columns
      # used in .select().  To enable this behaviour, include the flag :_brick_eager_load as the first
      # entry in your .select().
      # More information:  https://discuss.rubyonrails.org/t/includes-and-select-for-joined-data/81640
      def apply_column_aliases(relation)
        if !(@join_root_alias = relation.select_values.empty?) &&
            relation.select_values.first.to_s == "_brick_eager_load"
          relation.select_values.shift

          used_cols = Set.new
          # Find and expand out all column names being used in select(...)
          new_select_values = relation.select_values.map(&:to_s).each_with_object([]) do |col, s|
            if !col.include?(" ") # Pass it through if it's some expression (No chance for a simple column reference)
              if (col_parts = col.split(".")).length == 1
                table_name = relation.klass.table_name
                col = [table_name, col]
              else
                table_name = col_parts[0..-2].join(".")
                col = [table_name, col_parts.last]
              end
              used_cols.add(col)

              # Don't bother adding to the user selects here: The column will get picked up in the eager load aliases.
            else
              s << col
            end
          end
          if new_select_values.present?
            relation.select_values = new_select_values
          else
            relation.select_values.clear
          end

          @aliases ||= Aliases.new(join_root.each_with_index.map do |join_part, i|
            join_alias = join_part.table&.table_alias || join_part.table_name
            keys = [join_part.base_klass.primary_key] # Always include the primary key

            # # %%% Optional to include all foreign keys:
            # keys.concat(join_part.base_klass.reflect_on_all_associations.select { |a| a.belongs_to? }.map(&:foreign_key))

            # Add foreign keys out to referenced tables that we belongs_to
            # Note: @lorint's initial code checked for `child.reflection.belongs_to?`, but this seems to incorrectly
            # omit `ActiveRecord::Reflection::ThroughReflection`s and their chaining.
            join_part.children.each do |child|
              traversed_child_reflection = child.reflection

              while traversed_child_reflection.is_a?(Reflection::ThroughReflection)
                traversed_child_reflection = traversed_child_reflection.through_reflection
              end

              if traversed_child_reflection.belongs_to?
                keys << traversed_child_reflection.foreign_key
              end
            end

            # Add the foreign key that got us here -- "the train we rode in on" -- if we arrived from
            # a has_many or has_one:
            if join_part.is_a?(ActiveRecord::Associations::JoinDependency::JoinAssociation) &&
              !join_part.reflection.belongs_to?
              keys << join_part.reflection.foreign_key
            end
            keys = keys.compact # In case we're using composite_primary_keys

            selected_columns = []
            all_columns = []
            has_selected_column = false

            join_part.column_names.each_with_index do |column_name, j|
              column = Aliases::Column.new(column_name, "t#{i}_r#{j}")

              is_column_selected = used_cols.include?([join_alias, column_name])
              has_selected_column ||= is_column_selected

              # The user selects straight up contain the join alias or column *or* foreign or primary keys are involved.
              if is_column_selected || keys.find { |c| c == column_name }
                selected_columns << column
              end

              all_columns << column
            end

            Aliases::Table.new(
              join_part,
              if has_selected_column
                # Are there columns affected by `select`? Use those.
                selected_columns
              else
                # No columns affected by `select`? Fall back to projecting all columns.
                all_columns
              end,
            )
          end)
        end

        relation._select!(-> { aliases.columns })
      end
    end
  end
end
