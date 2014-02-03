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
  # We want the table to be named "authorizations".
  self.table_name = self.name.demodulize.underscore.pluralize

  # Include default Devise modules.
  devise :database_authenticatable, :rememberable, # These are authentication related.
         :recoverable, :registerable, :trackable, :validatable

  # Set some default values if the record is saved.
  before_save :default_values

  # Specifies the user entity join table name.
  #
  # @param join_table_name [Symbol] the user entity join table name.
  def self.joins(join_table_name)
    join_table_name = join_table_name.to_sym

    @join_table = Arel::Table.new(join_table_name)
    @association_name = @join_table.name.singularize.to_sym

    join_model = const_get("::#{@association_name.to_s.camelize}")
    @join_columns = join_model.table_exists? ? join_model.column_names - column_names : []

    belongs_to @association_name
  end

  # Overrides Devise's default behavior and attempts to join the user entity table.
  def self.find_first_by_auth_conditions(conditions)
    table = arel_table
    join_table = @join_table

    query = table.project(table[Arel.star])

    @join_columns.each do |column_name|
      query.project(join_table[column_name]).as(column_name.to_s)
    end

    query.join(join_table).on(table[reflections[@association_name].foreign_key].eq join_table[:id])

    conditions.each_pair do |column_name, value|
      query.where(join_table[column_name].eq value)
    end

    find_by_sql(query).first
  end

  # Sets default values for some columns if they haven't been provided.
  def default_values
    self.class_name ||= self.class.name
  end

  # Wrap the mixed in Devise method with one that additionally checks whether the role equals the scope/resource name.
  def active_for_authentication?
    super && class_name == self.class.name
  end

  # The email isn't required, because it resides in the joined user entity.
  def email_required?
    false
  end

  # The email can't change, because it resides in the joined user entity.
  def email_changed?
    false
  end
end
