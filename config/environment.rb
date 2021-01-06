# frozen_string_literal: true

require "byebug"
require "rails"
require "action_controller/railtie"
require "active_record"
require "active_record/railtie"
require "active_model_serializers"
require "factory_bot_rails"
require "scalient-rails"

# Instead of an a configuration-by-convention Rails directory structure, we load the inlined Rails app.
require_relative "../spec/support/rails_app"
