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

          if association.embed_in_root?
            if association.embed_in_root_key?
              hash = hash[association.embed_in_root_key] ||= {}
            end

            serialized_data = association_serializer.serializable_object

            if !association.polymorphic?
              key = association.root_key
            else
              key = object.send("#{association.name}_type").demodulize.underscore.pluralize
              serialized_data = serialized_data.map { |data| data[data[:type]] }
            end

            if hash.has_key?(key)
              hash[key].concat(serialized_data).uniq!
            else
              hash[key] = serialized_data
            end
          end
        end
      end
    end
  end
end
