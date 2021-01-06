# frozen_string_literal: true
#
# Copyright 2015 Scalient LLC
# All rights reserved.

require "scalient/rails/helpers/application_helper"

module Scalient
  module Rails
    class Engine < ::Rails::Engine
      isolate_namespace ::Scalient::Rails
    end

    ::Rails::Application.send(:include, ApplicationHelper)
  end
end
