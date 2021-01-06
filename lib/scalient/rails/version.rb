# frozen_string_literal: true
#
# Copyright 2013 Scalient LLC
# All rights reserved.

module Scalient
  module Rails
    # A module containing the gem version information.
    module Version
      # The major version.
      MAJOR = 1

      # The minor version.
      MINOR = 0

      # The patch version.
      PATCH = 0

      # Gets the String representation of the gem version.
      def self.to_s
        "#{MAJOR}.#{MINOR}.#{PATCH}"
      end
    end
  end
end
