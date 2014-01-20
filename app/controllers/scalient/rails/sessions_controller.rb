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
    json_resource_name = controller_name.singularize

    respond_to do |format|
      # Remap the session information to the Devise scope name, which will be picked up on for authentication purposes.
      format.json do
        request.params[resource_name] = request.params[json_resource_name]
        request.params.delete(json_resource_name)
      end

      format.all {}
    end

    # Copied from Devise::SessionsController.
    self.resource = warden.authenticate!(auth_options)
    set_flash_message(:notice, :signed_in) if is_flashing_format?
    redirect_path = after_sign_in_path_for(resource_name)
    sign_in(resource_name, resource)
    yield resource if block_given?

    respond_to do |format|
      format.any(*navigational_formats) { redirect_to redirect_path }

      # Respond with the new CSRF token.
      format.json do
        render json: {json_resource_name => {"id" => 0, "csrf_token" => form_authenticity_token}}
      end

      format.all { head :no_content }
    end
  end

  # Signs out of the Devise scope, with special JSON handling added by us.
  def destroy
    json_resource_name = controller_name.singularize

    # Copied from Devise::SessionsController.
    redirect_path = after_sign_out_path_for(resource_name)
    signed_out = (Devise.sign_out_all_scopes ? sign_out : sign_out(resource_name))
    set_flash_message :notice, :signed_out if signed_out && is_flashing_format?
    yield resource if block_given?

    respond_to do |format|
      format.any(*navigational_formats) { redirect_to redirect_path }

      # Respond with the new CSRF token.
      format.json do
        render json: {json_resource_name => {"id" => 0, "csrf_token" => form_authenticity_token}}
      end

      format.all { head :no_content }
    end
  end
end
