# frozen_string_literal: true

# Copyright 2014-2023 Roy Liu
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not
# use this file except in compliance with the License. You may obtain a copy of
# the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations under
# the License.

module Scalient
  module Rails
    class SessionsController < Devise::SessionsController
      # Signs in to the Devise scope, with special JSON handling added by us.
      def create
        # Copied from `Devise::SessionsController`.
        self.resource = warden.authenticate!(auth_options)
        set_flash_message!(:notice, :signed_in)
        sign_in(resource_name, resource)
        yield resource if block_given?

        # Important: Declare the `:json` response format *first* to ensure that it's used for requests with no format
        # preference (`*/*`). This is a sensible policy because browsers with human users will generate an `Accept`
        # header containing `text/html`.
        respond_to do |format|
          format.json do
            render json: response_json(find_message(:signed_in))
          end

          format.any(*navigational_formats) { redirect_to after_sign_in_path_for(resource_name) }
          format.all { head :no_content }
        end
      end

      # Gets the current session. Provided for RESTfulness.
      def show
        self.resource = warden.authenticate!(auth_options)

        respond_to do |format|
          format.json do
            render json: response_json("This is the current session.")
          end

          format.all { head :no_content }
        end
      end

      # Monkey patch this entire method until https://github.com/heartcombo/devise/pull/5319 is merged.
      def require_no_authentication
        assert_is_devise_resource!
        return unless is_navigational_format?

        no_input = devise_mapping.no_input_strategies

        authenticated = if no_input.present?
          args = no_input.dup.push scope: resource_name
          warden.authenticate?(*args)
        else
          warden.authenticated?(resource_name)
        end

        return unless authenticated && (resource = warden.user(resource_name))

        # This is the changed line to use `set_flash_message!` instead of `set_flash_message`.
        set_flash_message!(:alert, "already_authenticated", scope: "devise.failure")
        redirect_to after_sign_in_path_for(resource)
      end

      private

      def response_json(message)
        {id: 0, message: message, resource_name => resource.as_json}
      end
    end
  end
end
