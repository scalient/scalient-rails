# -*- coding: utf-8 -*-
#
# Copyright 2013 Scalient LLC
# All rights reserved.

module Scalient
  module Rails
    class Engine < ::Rails::Engine
      isolate_namespace Scalient::Rails

      initializer "scalient-rails.setup_vendor", :after => "ember_rails.setup_vendor", :group => :all do |app|
        variant = app.config.ember.variant || (::Rails.env.production? ? :production : :development)

        ember_path = Engine.root.join("vendor/assets/ember", variant.to_s)
        app.assets.prepend_path(ember_path.to_s) if ember_path.exist?
      end
    end
  end
end
