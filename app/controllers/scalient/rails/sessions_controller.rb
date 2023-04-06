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
        set_flash_message(:notice, :signed_in) if is_flashing_format?
        redirect_path = after_sign_in_path_for(resource_name)
        sign_in(resource_name, resource)
        yield resource if block_given?

        # Important: Declare the `:json` response format *first* to ensure that it's used for requests with no format
        # preference (`*/*`). This is a sensible policy because browsers with human users will generate an `Accept`
        # header containing `text/html`.
        respond_to do |format|
          format.json do
            render json: response_json(find_message(:signed_in))
          end

          format.any(*navigational_formats) { redirect_to redirect_path }
          format.all { head :no_content }
        end
      end

      # Signs out of the Devise scope, with special JSON handling added by us.
      def destroy
        # Copied from `Devise::SessionsController`.
        redirect_path = after_sign_out_path_for(resource_name)
        signed_out = (Devise.sign_out_all_scopes ? sign_out : sign_out(resource_name))
        set_flash_message(:notice, :signed_out) if signed_out && is_flashing_format?
        yield resource if block_given?

        respond_to do |format|
          format.any(*navigational_formats) { redirect_to redirect_path }
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

      private

      def response_json(message)
        {id: 0, message: message, resource_name => resource.as_json}
      end
    end
  end
end
