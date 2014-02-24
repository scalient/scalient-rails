# -*- coding: utf-8 -*-
#
# Copyright 2014 Roy Liu
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

ActiveModel::Serializer.setup do |config|
  config.embed = :ids
  config.embed_in_root = true
end

module ActiveModel
  class Serializer
    # Monkey patch broken "has_one" association behavior when used with the "root" option, and add support for
    # polymorphism.
    def embedded_in_root_associations
      associations = self.class._associations
      included_associations = filter(associations.keys)
      associations.each_with_object({}) do |(name, association), hash|
        if included_associations.include? name
          if association.embed_in_root?
            association_serializer = build_serializer(association)

            # Two associations could share the same root key.
            hash.merge! association_serializer.embedded_in_root_associations do |_, lhs, rhs|
              if lhs.is_a?(Array) && rhs.is_a?(Array)
                merged = lhs + rhs
                merged.uniq!
                merged
              else
                rhs
              end
            end

            serialized_data = association_serializer.serializable_object

            if !association.options[:polymorphic]
              key = association.root_key
            else
              id = object.send("#{association.name}_id")
              key = !id.nil? ? object.send("#{association.name}_type").demodulize.underscore.pluralize : nil
            end

            if hash.has_key?(key)
              (hash[key] ||= []).concat(serialized_data || []).uniq!
            else
              hash[key] = serialized_data
            end if !key.nil?
          end
        end
      end
    end

    # Monkey patch to add support for polymorphism.
    def associations
      associations = self.class._associations
      included_associations = filter(associations.keys)
      associations.each_with_object({}) do |(name, association), hash|
        if included_associations.include? name
          if !association.options[:polymorphic]
            if association.embed_ids?
              hash[association.key] = serialize_ids association
            elsif association.embed_objects?
              hash[association.embedded_key] = serialize association
            end
          else
            hash[association.embedded_key] = serialize_polymorphic_id association
          end
        end
      end
    end

    # Serialize the polymorphic id as the tuple "(id, type)".
    def serialize_polymorphic_id(association)
      id = object.send("#{association.name}_id")
      !id.nil? ? {id: id, type: object.send("#{association.name}_type").demodulize.underscore} : nil
    end
  end
end
