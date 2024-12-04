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
          used_cols = {}
          # Find and expand out all column names being used in select(...)
          new_select_values = relation.select_values.map(&:to_s).each_with_object([]) do |col, s|
            unless col.include?(" ") # Pass it through if it's some expression (No chance for a simple column reference)
              col = if (col_parts = col.split(".")).length == 1
                [col]
              else
                [col_parts[0..-2].join("."), col_parts.last]
              end
              used_cols[col] = nil
            end
            s << col
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
            join_part.children.each { |child| keys << child.reflection.foreign_key if child.reflection.belongs_to? }

            # Add the foreign key that got us here -- "the train we rode in on" -- if we arrived from
            # a has_many or has_one:
            if join_part.is_a?(ActiveRecord::Associations::JoinDependency::JoinAssociation) &&
              !join_part.reflection.belongs_to?
              keys << join_part.reflection.foreign_key
            end
            keys = keys.compact # In case we're using composite_primary_keys
            j = 0
            columns = join_part.column_names.each_with_object([]) do |column_name, s|
              # Include columns chosen in select(...) as well as the PK and any relevant FKs
              if used_cols.keys.find { |c| (c.length == 1 || c.first == join_alias) && c.last == column_name } ||
                keys.find { |c| c == column_name }
                s << Aliases::Column.new(column_name, "t#{i}_r#{j}")
              end
              j += 1
            end
            Aliases::Table.new(join_part, columns)
          end)
        end

        relation._select!(-> { aliases.columns })
      end
    end
  end
end
