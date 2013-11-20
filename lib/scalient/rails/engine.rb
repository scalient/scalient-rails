# -*- coding: utf-8 -*-
#
# Copyright 2013 Scalient LLC
# All rights reserved.

module Scalient
  module Rails
    class Engine < ::Rails::Engine
      isolate_namespace Scalient::Rails
    end
  end
end
