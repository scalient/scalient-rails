# frozen_string_literal: true

class ReferenceSerializer < ApplicationSerializer
  belongs_to_reluctant :referrer, polymorphic: true

  # Mix things up with an explicit option.
  belongs_to_reluctant :referent, polymorphic: true, class_name: "Reference"
end
