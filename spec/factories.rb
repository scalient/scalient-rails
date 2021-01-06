# frozen_string_literal: true

FactoryBot.define do
  factory :user, class: "User" do
    name { "Harry Bovik" }
  end

  factory :users_organization_cmu, class: "UsersOrganization" do
    association :user, factory: :user
    association :organization, factory: :organization_cmu
  end

  factory :organization_cmu, class: "Organization" do
    name { "Carnegie Mellon University" }
  end

  factory :users_organization_home, class: "UsersOrganization" do
    association :user, factory: :user
    association :organization, factory: :organization_home
  end

  factory :organization_home, class: "Organization" do
    name { nil }
  end

  factory :reference_user_to_organization_home, class: "Reference" do
    association :referrer, factory: :user
    association :referent, factory: :organization_home
  end
end
