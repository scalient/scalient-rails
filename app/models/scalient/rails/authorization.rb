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
  class << self
    attr_reader :scope_name
  end

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
  def self.joins(join_table_name = :users)
    join_table_name = join_table_name.to_sym

    @join_table = Arel::Table.new(join_table_name)

    belongs_to join_table_name.to_s.singularize.to_sym
  end

  # Specifies the Devise scope that this class is an authorization for.
  #
  # @param scope_name [String] the Devise scope name.
  def self.authentication_scope(scope_name = "user")
    @scope_name = scope_name.to_s
  end

  # Overrides Devise's default behavior and attempts to join the user entity table.
  def self.find_first_by_auth_conditions(conditions)
    table = arel_table
    join_table = @join_table

    association_name = reflections[join_table.name.singularize.to_sym].foreign_key.to_sym

    query = table.project(table[Arel.star])

    conditions.each_key do |column_name|
      query.project(join_table[column_name]).as(column_name.to_s)
    end

    query.join(join_table).on(table[association_name].eq join_table[:id])

    conditions.each_pair do |column_name, value|
      query.where(join_table[column_name].eq value)
    end

    find_by_sql(query).first
  end

  # Sets default values for some columns if they haven't been provided.
  def default_values
    self.scope ||= self.class.scope_name || self.class.name.underscore.gsub("/", "_")
  end

  # Wrap the mixed in Devise method with one that additionally checks whether the role equals the scope/resource name.
  def active_for_authentication?
    super && (scope == self.class.scope_name || scope == self.class.name.underscore.gsub("/", "_"))
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
