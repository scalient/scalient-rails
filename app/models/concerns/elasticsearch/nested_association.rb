# frozen_string_literal: true
#
# Copyright 2020 The Affective Computing Company
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

module Elasticsearch
  module NestedAssociation
    extend ActiveSupport::Concern

    included do
      mattr_accessor :denormalized_reflections_to_options, instance_accessor: false

      self.denormalized_reflections_to_options = {}
    end

    def nested_association_data
      # Options can include `key` and `mapper`.
      Hash[self.class.denormalized_reflections_to_options.map do |reflection, options|
        key = options[:key]
        mapper = options[:mapper]

        [key, self.association(reflection.name).scope.map { |record| record.instance_exec(&mapper) }]
      end]
    end

    class_methods do
      def reindex_parent_records(records)
        if defined?(super)
          super
        end
      end

      def nested_for_search(association_name, attribute_name, options = {})
        options = ActiveSupport::HashWithIndifferentAccess.new(options)
        reflection = reflections[association_name.to_s]

        options_only_reindex_on = options[:only_reindex_on]
        options_key = options[:key]

        if !options_key
          options_key = reflection.name.to_s.singularize

          if !attribute_name.is_a?(Proc)
            options_key = "#{options_key}_#{attribute_name}"
          end

          if reflection.collection?
            options_key = options_key.pluralize
          end
        end

        # The user can return an arbitrary nested document if `attribute_name` is a `Proc`.
        denormalized_reflections_to_options[reflection] = {
            key: options_key,
            mapper: if !attribute_name.is_a?(Proc)
              Proc.new do
                read_attribute(attribute_name)
              end
            else
              attribute_name
            end
        }

        reverse_reflections = if options_only_reindex_on
          if !options_only_reindex_on.is_a?(Array)
            options_only_reindex_on = [options_only_reindex_on]
          end

          options_only_reindex_on = options_only_reindex_on.map(&:to_sym)

          reflection.chain.select do |reverse_reflection|
            options_only_reindex_on.include?(reverse_reflection.name)
          end
        else
          reflection.chain
        end

        base_class = self

        reverse_reflections.each do |reverse_reflection|
          intermediate_class = reverse_reflection.klass

          intermediate_class.class_eval do
            before_destroy do
              # Fetch and cache the reverse reflection scopes because many of the intermediate records (including this
              # one) may no longer exist after destruction.
              (@cached_reflection_scopes ||= []).push(
                  ActiveRecord::Associations::ReflectionScope.scope(reverse_reflection, true).
                      where(intermediate_class.arel_table[:id].eq self.id).to_a
              )
            end

            after_commit do
              if destroyed?
                # If this record was destroyed, then we look for cached scopes that were retrieved before the database
                # query.
                parent_records = (@cached_reflection_scopes || []).reduce([]) do |result, cached_scope|
                  result + cached_scope
                end.uniq

                base_class.reindex_parent_records(parent_records)

                if @cached_reflection_scopes
                  remove_instance_variable(:@cached_reflection_scopes)
                end
              else
                # ... otherwise, just reindex the records of reverse reflection.
                base_class.reindex_parent_records(
                    ActiveRecord::Associations::ReflectionScope.scope(reverse_reflection, true).
                        where(intermediate_class.arel_table[:id].eq self.id)
                )
              end
            end

            after_rollback do
              if @cached_reflection_scopes
                remove_instance_variable(:@cached_reflection_scopes)
              end
            end
          end
        end

        nil
      end
    end
  end
end
