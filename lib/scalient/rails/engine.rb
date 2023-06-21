# frozen_string_literal: true

# Copyright 2015-2023 Scalient LLC
# All rights reserved.

require "scalient/rails/helpers/application_helper"

module Scalient
  module Rails
    class Engine < ::Rails::Engine
      isolate_namespace ::Scalient::Rails

      config.uppy_s3_multipart = ActiveSupport::OrderedOptions.new
      config.uppy_s3_multipart.base_controller = "ActionController::Base"
      config.uppy_s3_multipart.prefix = nil
      config.uppy_s3_multipart.public = false
      config.uppy_s3_multipart.options = {}
    end

    ::Rails::Application.include ApplicationHelper
  end
end
