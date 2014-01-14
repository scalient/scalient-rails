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

class Scalient::Rails::UserAuthorization < ActiveRecord::Base
  # We want the table to be named "user_authorizations".
  self.table_name = self.name.demodulize.underscore.pluralize

  # Include default Devise modules.
  devise :database_authenticatable, :rememberable, # These are authentication related.
         :recoverable, :registerable, :trackable, :validatable

  # Wrap the mixed in Devise method with one that additionally checks whether the role equals the scope/resource name.
  def valid_for_authentication?
    super && scope == self.class.name.underscore.gsub("/", "_")
  end
end
