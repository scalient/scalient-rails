# frozen_string_literal: true

#
# Copyright 2021 Scalient LLC
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
  module Modeling
    module PolymorphicBuilder
      extend ActiveSupport::Concern

      included do
        send(:extend, ClassMethods)
      end

      module ClassMethods
        def build_polymorphic(association_name)
          association_name = association_name.to_s

          reflection = reflections[association_name]
          foreign_type = reflection.foreign_type

          if !foreign_type
            raise "Reflection `#{association_name}` doesn't seem to be polymorphic"
          end

          define_method("build_#{association_name}") do |params|
            foreign_class = read_attribute(foreign_type).safe_constantize

            if !foreign_class
              raise "Foreign class `#{foreign_class}` not found"
            end

            if id = params[foreign_class.primary_key]
              if record = foreign_class.find_by_id(id)
                record
              else
                raise_nested_attributes_record_not_found!(association_name, id)
              end
            else
              send("#{association_name}=", foreign_class.new(params))
            end
          end
        end
      end
    end
  end
end
