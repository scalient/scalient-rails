# -*- coding: utf-8 -*-
#
# Copyright 2014 Roy Liu
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

class Scalient::Rails::SessionsController < Devise::SessionsController
  # The sign-in action doesn't need CSRF protection, which guards against hijacked cookies, and not against sign-ins
  # with usernames and passwords. In fact, in the case of session cookie expiration with JavaScript MVCs like Ember.js,
  # the user may be left in a permanent bind (short of a browser reload):
  #
  #   1. The user signs in successfully.
  #   2. Rails helpfully invalidates the new session cookie because the CSRF token was invalid.
  #   3. The user is forced to sign in again.
  skip_before_filter :verify_authenticity_token, only: [:create]

  # Signs in to Devise scope, with special JSON handling added by us.
  def create
    json_resource_name = nil

    respond_to do |format|
      # Remap the session information to the Devise scope name, which will be picked up on for authentication purposes.
      format.json do
        json_resource_name = controller_name.singularize
        request.params[resource_name] = request.params[json_resource_name]
        request.params.delete(json_resource_name)
      end
    end

    # Copied from Devise::SessionsController.
    self.resource = warden.authenticate!(auth_options)
    set_flash_message(:notice, :signed_in) if is_flashing_format?
    sign_in(resource_name, resource)
    yield resource if block_given?

    respond_with(resource, :location => after_sign_in_path_for(resource)) do |format|
      # Respond with the new CSRF token.
      format.json do
        render json: {json_resource_name => {"id" => 0, "csrf_token" => form_authenticity_token}}
      end
    end
  end
end
