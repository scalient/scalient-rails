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

    it "serializes nested associations reached by nested attribute setting under the `update` action" do
      user = FactoryBot.create(:user)
      users_organization_cmu = FactoryBot.create(:users_organization_cmu, user: user)

      patch :update, params: {
          class_name: "User", id: user.id, user: {
              # Test nested posting to a `has_many` association.
              users_organizations_attributes: [
                  # Update an existing record.
                  {
                      id: users_organization_cmu.id,
                      admin: true
                  },
                  # Create a new record.
                  {
                      # TODO: Why do we need a placeholder attribute at all, and is this is a bug in
                      # `ActiveRecord::NestedAttributes::ClassMethods`? Removing it causes the `UsersOrganization`
                      # record above to be modified.
                      id: nil,
                      # Test nested posting to a `belongs_to` association.
                      organization_attributes: {
                          name: "Embedded Through `UsersOrganization`"
                      }
                  }
              ],
              # Test nested posting to a `has_one` association.
              home_users_organization_attributes: {
                  home: true,
                  # Test nested posting to a `belongs_to` association.
                  organization_attributes: {
                      id: nil
                  }
              },
              # Test nested posting to a `has_one` polymorphic association.
              references_attributes: [
                  {
                      referent_type: "User",
                      # Test nested posting to a `belongs_to` polymorphic association.
                      referent_attributes: {
                          name: "Embedded Through `Reference`"
                      }
                  }
              ]
          }
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
          },
          {
            "id": "3",
            "type": "users-organizations"
          }
        ]
      },
      "home-users-organization": {
        "data": {
          "id": "2",
          "type": "users-organizations"
        }
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
        "admin": true,
        "home": false,
        "user-id": "1",
        "organization-id": "1"
      }
    },
    {
      "id": "3",
      "type": "users-organizations",
      "attributes": {
        "admin": false,
        "home": false,
        "user-id": "1"
      },
      "relationships": {
        "organization": {
          "data": {
            "id": "3",
            "type": "organizations"
          }
        }
      }
    },
    {
      "id": "3",
      "type": "organizations",
      "attributes": {
        "name": "Embedded Through `UsersOrganization`"
      }
    },
    {
      "id": "2",
      "type": "users-organizations",
      "attributes": {
        "admin": false,
        "home": true,
        "user-id": "1"
      },
      "relationships": {
        "organization": {
          "data": {
            "id": "2",
            "type": "organizations"
          }
        }
      }
    },
    {
      "id": "2",
      "type": "organizations",
      "attributes": {
        "name": null
      }
    },
    {
      "id": "1",
      "type": "references",
      "attributes": {
        "referrer-id": "1",
        "referrer-type": "User"
      },
      "relationships": {
        "referent": {
          "data": {
            "id": "2",
            "type": "users"
          }
        }
      }
    },
    {
      "id": "2",
      "type": "users",
      "attributes": {
        "name": "Embedded Through `Reference`"
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
