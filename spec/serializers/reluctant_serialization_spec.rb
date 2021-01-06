# frozen_string_literal: true

require "spec_helper"

describe Scalient::Serializer::Reluctant do
  describe Api::PolymorphicController, type: :controller do
    it "refuses to serialize `has_many_reluctant` and `has_one_reluctant` associations which aren't preloaded" do
      user = FactoryBot.create(:user)
      FactoryBot.create(:users_organization_cmu, user: user)
      FactoryBot.create(:users_organization_home, user: user)

      get :show, params: {class_name: "User", id: user.id}

      expect(JSON.pretty_generate(JSON.parse(response.body))).to(
          eq(<<EOS.strip
{
  "data": {
    "id": "1",
    "type": "users",
    "attributes": {
      "name": "Harry Bovik"
    }
  }
}
EOS
          )
      )
    end

    it "serializes associations which are preloaded" do
      user = FactoryBot.create(:user)
      FactoryBot.create(:users_organization_cmu, user: user)

      get :show, params: {
          class_name: "User", id: user.id, includes: [:home_users_organization, {users_organizations: :organization}]
      }

      expect(JSON.pretty_generate(JSON.parse(response.body))).to(
          eq(<<EOS.strip
{
  "data": {
    "id": "1",
    "type": "users",
    "attributes": {
      "name": "Harry Bovik"
    },
    "relationships": {
      "users-organizations": {
        "data": [
          {
            "id": "1",
            "type": "users-organizations"
          }
        ]
      },
      "home-users-organization": {
        "data": null
      }
    }
  },
  "included": [
    {
      "id": "1",
      "type": "users-organizations",
      "attributes": {
        "admin": false,
        "home": false
      },
      "relationships": {
        "user": {
          "data": {
            "id": "1",
            "type": "users"
          }
        },
        "organization": {
          "data": {
            "id": "1",
            "type": "organizations"
          }
        }
      }
    },
    {
      "id": "1",
      "type": "organizations",
      "attributes": {
        "name": "Carnegie Mellon University"
      }
    }
  ]
}
EOS
          )
      )
    end

    it "serializes the foreign keys of `belongs_to` associations which aren't preloaded" do
      user = FactoryBot.create(:user)
      users_organization_home = FactoryBot.create(:users_organization_home, user: user)
      FactoryBot.create(
          :reference_user_to_organization_home,
          referrer: user,
          referent: users_organization_home.organization
      )

      get :show, params: {
          class_name: "User", id: user.id, includes: [:users_organizations, :references]
      }

      # Note how normal and polymorphic `belongs_to` associations are covered.
      expect(JSON.pretty_generate(JSON.parse(response.body))).to(
          eq(<<EOS.strip
{
  "data": {
    "id": "1",
    "type": "users",
    "attributes": {
      "name": "Harry Bovik"
    },
    "relationships": {
      "users-organizations": {
        "data": [
          {
            "id": "1",
            "type": "users-organizations"
          }
        ]
      },
      "references": {
        "data": [
          {
            "id": "1",
            "type": "references"
          }
        ]
      }
    }
  },
  "included": [
    {
      "id": "1",
      "type": "users-organizations",
      "attributes": {
        "admin": false,
        "home": false,
        "organization-id": "1"
      },
      "relationships": {
        "user": {
          "data": {
            "id": "1",
            "type": "users"
          }
        }
      }
    },
    {
      "id": "1",
      "type": "references",
      "attributes": {
        "referent-id": "1",
        "referent-type": "Organization"
      },
      "relationships": {
        "referrer": {
          "data": {
            "id": "1",
            "type": "users"
          }
        }
      }
    }
  ]
}
EOS
          )
      )
    end
  end
end
