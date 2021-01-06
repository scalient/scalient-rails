# frozen_string_literal: true

class UsersOrganization < ApplicationRecord
  include Scalient::Serializer::NestedAttributesWatcher

  belongs_to :user
  belongs_to :organization

  accepts_nested_attributes_for :user, :organization, allow_destroy: true

  attribute :admin, :boolean, default: false
  attribute :home, :boolean, default: false
end
