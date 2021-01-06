# frozen_string_literal: true

class OrganizationSerializer < ApplicationSerializer
  attributes :name

  has_many_reluctant :users_organizations
end
