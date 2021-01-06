# frozen_string_literal: true

class UserSerializer < ApplicationSerializer
  attributes :name

  has_many_reluctant :users_organizations

  has_one_reluctant :home_users_organization

  has_many_reluctant :references
end
