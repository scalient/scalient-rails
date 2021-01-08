# frozen_string_literal: true

require "spec_helper"

describe Scalient::Serializer::NestedAttributesWatcher do
  it "resets the watcher state on `ApplicationRecord#reload`" do
    user = FactoryBot.create(:user)
    user.assign_attributes(
        {
            references_attributes: [
                {
                    referent_type: "User",
                    referent_attributes: {
                        name: "Embedded Through `Reference`"
                    }
                }
            ]
        }
    )

    expect(user.nested_association_was_updated?(:references)).to eq(true)

    user.reload

    expect(user.nested_association_was_updated?(:references)).to eq(false)
  end
end
