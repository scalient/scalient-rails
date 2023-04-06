# frozen_string_literal: true

# Copyright 2023 Roy Liu
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
    class PasswordsController < Devise::PasswordsController
      # Initiates the password reset request, with special JSON handling added by us.
      def create
        self.resource = resource_class.send_reset_password_instructions(resource_params)
        yield resource if block_given?

        # Important: Declare the `:json` response format *first* to ensure that it's used for requests with no format
        # preference (`*/*`). This is a sensible policy because browsers with human users will generate an `Accept`
        # header containing `text/html`.
        respond_to do |format|
          format.json do
            if successfully_sent?(resource)
              render json: response_json(
                find_message(Devise.paranoid ? :send_paranoid_instructions : :send_instructions)
              )
            else
              render json: response_json(error_message), status: :unprocessable_entity
            end
          end

          format.any(*navigational_formats) do
            if successfully_sent?(resource)
              redirect_to after_sending_reset_password_instructions_path_for(resource_name)
            else
              render action: "new", status: :unprocessable_entity
            end
          end

          format.all { head :no_content }
        end
      end

      # Updates the user record with their desired password, with special JSON handling added by us.
      def update
        self.resource = resource_class.reset_password_by_token(resource_params)
        yield resource if block_given?

        if resource.errors.empty?
          resource.unlock_access! if unlockable?(resource)
          if Devise.sign_in_after_reset_password
            flash_message = resource.active_for_authentication? ? :updated : :updated_not_active
            set_flash_message!(:notice, flash_message)
            resource.after_database_authentication
            sign_in(resource_name, resource)
          else
            set_flash_message!(:notice, :updated_not_active)
          end

          respond_to do |format|
            format.json do
              render json: response_json(find_message(:updated))
            end

            format.any(*navigational_formats) do
              redirect_to after_resetting_password_path_for(resource)
            end

            format.all { head :no_content }
          end
        else
          set_minimum_password_length

          respond_to do |format|
            format.json do
              render json: response_json(error_message), status: :unprocessable_entity
            end

            format.any(*navigational_formats) do
              render action: "new", status: :unprocessable_entity
            end

            format.all { head :no_content }
          end
        end
      end

      private

      def response_json(message)
        body = {id: 0, message: message}

        if resource.errors.size > 0
          body[:errors] = resource.errors.as_json
        end

        body
      end

      def error_message
        find_message("errors.messages.not_saved",
                     scope: "", count: resource.errors.count,
                     resource: resource.class.model_name.human.downcase)
      end
    end
  end
end
