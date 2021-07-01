# frozen_string_literal: true

# Adapted from `https://github.com/rails-api/active_model_serializers/blob/0-10-stable/test/support/isolated_unit.rb`.

# Note:
# It is important to keep this file as light as possible
# the goal for tests that require this is to test booting up
# rails from an empty state, so anything added here could
# hide potential failures
#
# It is also good to know what is the bare minimum to get
# Rails booted up.

module Rspec
  module Rails
    module_function

    # Make a very basic app, without creating the whole directory structure.
    # Is faster and simpler than generating a Rails app in a temp directory
    def make_basic_app
      require "rails"
      require "action_controller/railtie"

      app = Class.new(::Rails::Application) do
        config.eager_load = false
        config.session_store :cookie_store, key: "_rspec-rails_session"
        config.active_support.deprecation = :log
        config.active_support.test_order = :parallel
        config.log_level = :info
        # Set a fake logger to avoid creating the log directory automatically
        fake_logger = Logger.new(nil)
        config.logger = fake_logger
        ::Rails.application.routes.default_url_options = {host: "rspec-rails.io"}
      end

      def app.name
        "RspecRailsApp"
      end

      if app.respond_to?(:secrets)
        app.secrets.secret_key_base = "deadbeef"
      end

      @app = app

      if block_given?
        yield @app
      end

      @app.initialize!
    end
  end
end
