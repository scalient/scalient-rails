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

class Scalient::Rails::Authorization < ActiveRecord::Base
  extend Forwardable

  # We want the table to be named "authorizations".
  self.table_name = self.name.demodulize.underscore.pluralize

  # Include default Devise modules.
  devise :database_authenticatable, :rememberable, # These are authentication related.
         :trackable

  # Specifies the user entity join table name.
  #
  # @param join_table_name [Symbol] the user entity join table name.
  def self.joins(join_table_name)
    join_table_name = join_table_name.to_sym

    @join_table = Arel::Table.new(join_table_name)
    @association_name = @join_table.name.singularize.to_sym

    belongs_to @association_name

    # Forward these password-related invocations to the joined user entity.
    def_delegators @association_name, :after_database_authentication, :authenticatable_salt, :valid_password?
  end

  # Overrides Devise's default behavior and attempts to join the user entity table.
  def self.find_first_by_auth_conditions(conditions)
    query = includes(@association_name)

    conditions.each_pair do |column_name, value|
      query = query.where(@join_table[column_name].eq value)
    end

    query = query.references(@association_name)

    query.first
  end
end
