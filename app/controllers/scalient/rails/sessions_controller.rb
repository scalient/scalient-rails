# -*- coding: utf-8 -*-
#
# Copyright 2014-2017 Roy Liu
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
  # Renders the Devise sign-in page.
  def new
    self.resource = resource_class.new
    clean_up_passwords(resource)
    yield resource if block_given?

    respond_to do |format|
      format.any(*navigational_formats) { render serialize_options(resource) }
      format.all { head :no_content }
    end
  end

  # Signs in to the Devise scope, with special JSON handling added by us.
  def create
    session_resource_name = controller_name.singularize

    respond_to do |format|
      # Remap the session information to the Devise scope name, which will be picked up on for authentication purposes.
      format.json do
        request.params[resource_name] = request.params[session_resource_name]
        request.params.delete(session_resource_name)
      end

      format.all {}
    end

    # Copied from `Devise::SessionsController`.
    self.resource = warden.authenticate!(auth_options)
    set_flash_message(:notice, :signed_in) if is_flashing_format?
    redirect_path = after_sign_in_path_for(resource_name)
    sign_in(resource_name, resource)
    yield resource if block_given?

    respond_to do |format|
      format.any(*navigational_formats) { redirect_to redirect_path }

      format.json do
        render json: session_resource(0, find_message(:signed_in), resource)
      end

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
    self.resource = resource_class.new

    respond_to do |format|
      format.json do
        render json: session_resource(0, "This is the current session.")
      end

      format.all { head :no_content }
    end
  end

  # Use the translations for `Devise::SessionsController`.
  def translation_scope
    "devise.sessions"
  end

  private

  # Attempts to retrieve the session resource to take advantage of serialization.
  def session_resource(id, message, resource = nil)
    model = controller_path.classify.safe_constantize

    if model
      model.new(id: id, message: message, resource_name => resource)
    else
      # Default to JSON if the session resource model isn't found.
      {id: id, message: message, resource_name => resource.as_json}
    end
  end
end
