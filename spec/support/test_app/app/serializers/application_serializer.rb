# frozen_string_literal: true

class ApplicationSerializer < ActiveModel::Serializer
  include Scalient::Serializer::Reluctant
end
