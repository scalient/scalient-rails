# frozen_string_literal: true

class Reference < ApplicationRecord
  belongs_to :referrer, polymorphic: true
  belongs_to :referent, polymorphic: true, optional: true

  accepts_nested_attributes_for :referrer, :referent, allow_destroy: true

  # Switch things up and deliberately invoke this *after* `accepts_nested_attributes_for`.
  include Scalient::Serializer::NestedAttributesWatcher

  # For nested attributes.

  def build_referrer(params)
    self.referrer = referrer_type.constantize.new(params)
  end

  def build_referent(params)
    self.referent = referent_type.constantize.new(params)
  end
end
