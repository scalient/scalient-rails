# frozen_string_literal: true

class User < ApplicationRecord
  include Scalient::Serializer::NestedAttributesWatcher

  has_many :users_organizations
  has_many :organizations, through: :users_organizations

  has_one :home_users_organization, lambda { where(home: true) }, class_name: "UsersOrganization"
  has_one :home_organization, through: :home_users_organization, source: "organization", class_name: "Organization"

  has_many :references, as: :referrer

  accepts_nested_attributes_for :users_organizations, :home_users_organization, :references, allow_destroy: true

  attribute :name, :string
  validates :name, presence: true
end
