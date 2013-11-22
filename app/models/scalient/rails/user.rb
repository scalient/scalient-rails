# -*- coding: utf-8 -*-
#
# Copyright 2013 Scalient LLC
# All rights reserved.

class Scalient::Rails::User < ActiveRecord::Base
  # We don't want the table name to be "scalient_rails_user".
  self.table_name = "users"

  # Include default Devise modules.
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable
end
