# frozen_string_literal: true

require "factory_bot_rails"

require_relative "rspec/rails/app_factory"

module Scalient
  module Rails
    TestApplication = Rspec::Rails.make_basic_app do |app|
      app.configure do
        config.active_support.test_order = :random
        config.action_controller.perform_caching = true
        config.action_controller.cache_store = :memory_store
        config.action_dispatch.return_only_media_type_on_content_type = true
        config.filter_parameters += [:password]
        config.root = File.expand_path("../test_app", __FILE__)
        config.factory_bot.definition_file_paths += [File.expand_path("../../factories", __FILE__)]
      end
    end

    routes = TestApplication.routes

    routes.draw do
      get ":controller(/:action(/:id))"
      get ":controller(/:action)"
      post ":controller(/:action)"
      patch ":controller(/:action(/:id))"
      delete ":controller(/:action(/:id))"
    end

    ActionController::Base.send(:include, routes.url_helpers)
  end
end
