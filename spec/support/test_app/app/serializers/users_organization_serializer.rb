# frozen_string_literal: true

class UsersOrganizationSerializer < ApplicationSerializer
  attributes :admin, :home

  belongs_to_reluctant :user

  # Mix things up with an explicit option.
  belongs_to_reluctant :organization, class_name: "UsersOrganization"
end
