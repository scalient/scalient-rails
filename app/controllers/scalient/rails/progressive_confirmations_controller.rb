# frozen_string_literal: true

# Copyright 2024 Roy Liu
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
    class ProgressiveConfirmationsController < Devise::ConfirmationsController
      def create
        self.resource = resource_class.send_confirmation_instructions(resource_params)
        yield resource if block_given?

        # Important: Declare the `:json` response format *first* to ensure that it's used for requests with no format
        # preference (`*/*`). This is a sensible policy because browsers with human users will generate an `Accept`
        # header containing `text/html`.
        if successfully_sent?(resource)
          respond_to do |format|
            format.json do
              render json: response_json(
                find_message(Devise.paranoid ? :send_paranoid_instructions : :send_instructions),
              )
            end

            format.any(*navigational_formats) do
              redirect_to after_resending_confirmation_instructions_path_for(resource_name)
            end

            format.all { head :no_content }
          end
        else
          respond_to do |format|
            format.json do
              render json: response_json(error_message("errors.messages.not_saved")), status: :unprocessable_entity
            end

            format.any(*navigational_formats) do
              render action: "new", status: :unprocessable_entity
            end

            format.all { head :no_content }
          end
        end
      end

      def show
        self.resource = if (confirmation_token = params.fetch(:confirmation_token))
          resource_class.find_or_initialize_with_error_by(:confirmation_token, confirmation_token, :invalid)
        else
          new.tap do |record|
            record.errors.add(:confirmation_token, :not_found)
          end
        end

        yield resource if block_given?

        if resource.errors.empty?
          set_flash_message!(:notice, :confirmed)

          respond_to do |format|
            format.json do
              render json: response_json(find_message(:confirmed))
            end

            format.any(*navigational_formats) do
              redirect_to after_confirmation_path_for(resource_name, resource)
            end

            format.all { head :no_content }
          end
        else
          respond_to do |format|
            format.json do
              render json: response_json(error_message("errors.messages.not_found")), status: :not_found
            end

            format.any(*navigational_formats) do
              render action: "new", status: :not_found
            end

            format.all { head :no_content }
          end
        end
      end

      def confirm
        self.resource = if (confirmation_token = resource_params.fetch(:confirmation_token))
          resource_class.find_or_initialize_with_error_by(:confirmation_token, confirmation_token, :invalid)
        else
          new.tap do |record|
            record.errors.add(:confirmation_token, :not_found)
          end
        end

        # The record could already have errors from failed retrieval.
        if resource.errors.empty?
          resource.update(
            resource_params.permit(:password, :password_confirmation).slice(:password, :password_confirmation),
          )
        end

        yield resource if block_given?

        # The record could have accumulated errors from saving.
        if resource.errors.empty?
          self.resource = resource_class.confirm_by_token(confirmation_token)
          set_flash_message!(:notice, :confirmed)
          sign_in(resource_name, resource)

          respond_to do |format|
            format.json do
              render json: response_json(find_message(:confirmed))
            end

            format.any(*navigational_formats) do
              redirect_to after_confirmation_path_for(resource_name, resource)
            end

            format.all { head :no_content }
          end
        else
          respond_to do |format|
            format.json do
              render json: response_json(error_message("errors.messages.not_saved")), status: :unprocessable_entity
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
        body = {id: 0, message:}

        if resource.errors.size > 0
          body[:errors] = resource.errors.as_json
        end

        body
      end

      def error_message(i18n_path)
        find_message(
          i18n_path,
          scope: "", count: resource.errors.count,
          resource: resource.class.model_name.human.downcase,
        )
      end
    end
  end
end
