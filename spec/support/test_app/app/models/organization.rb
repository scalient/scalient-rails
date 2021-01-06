# frozen_string_literal: true

class Organization < ApplicationRecord
  include Scalient::Serializer::NestedAttributesWatcher

  has_many :users_organizations
  has_many :users, through: :users_organizations

  accepts_nested_attributes_for :users_organizations, allow_destroy: true

  attribute :name, :string
end
