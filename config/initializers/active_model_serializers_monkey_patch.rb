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

require "active_model/serializer"

module ActiveModel
  # Monkey patch polymorphism into `DefaultSerializer`.
  class DefaultSerializer
    def initialize(object, options={})
      @object = object
      @wrap_in_array = options[:_wrap_in_array]
      @polymorphic = options[:polymorphic]
    end

    def serializable_object(options={})
      instrument('!serialize') do
        return [] if @object.nil? && @wrap_in_array
        hash = @object.as_json

        hash = {:type => type_name(@object), type_name(@object) => hash} \
          if @polymorphic && !@object.nil?

        @wrap_in_array ? [hash] : hash
      end
    end

    private

    def type_name(elem)
      elem.class.to_s.demodulize.underscore.to_sym
    end
  end

  class Serializer
    # Add support for polymorphism.
    def embedded_in_root_associations
      associations = self.class._associations
      included_associations = filter(associations.keys)
      associations.each_with_object({}) do |(name, association), hash|
        if included_associations.include? name
          association_serializer = build_serializer(association)
          hash.merge!(association_serializer.embedded_in_root_associations) do |key, oldval, newval|
            [newval, oldval].flatten.uniq
          end

          if association.embed_in_root?
            if association.embed_in_root_key?
              hash = hash[association.embed_in_root_key] ||= {}
            end

            serialized_data = association_serializer.serializable_object

            if !association.polymorphic?
              key = association.root_key

              if hash.has_key?(key)
                hash[key].concat(serialized_data).uniq!
              else
                hash[key] = serialized_data
              end
            else
              serialized_data.each do |datum|
                type = datum[:type]
                key = type.to_s.pluralize
                datum = datum[type]

                if hash.has_key?(key)
                  hash[key].push(datum).uniq!
                else
                  hash[key] = [datum]
                end
              end
            end
          end
        end
      end
    end
  end
end
