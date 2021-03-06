# frozen_string_literal: true
#
# Copyright 2015-2019 Roy Liu
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
  module Pundit
    extend ActiveSupport::Concern

    included do
      include ::Pundit

      rescue_from ::Pundit::NotAuthorizedError, with: :not_authorized

      def not_authorized
        referrer = request.referrer
        is_self_redirect_loop = referrer && URI(request.original_url) == URI(referrer)

        if referrer && defined?(Devise)
          is_sign_in_redirect_loop = !!Devise.mappings.find do |scope, _|
            sign_in_helper = "new_#{scope.to_s}_session_url"

            if respond_to?(sign_in_helper) && URI(referrer) == URI(send(sign_in_helper))
              scope
            else
              nil
            end
          end
        else
          is_sign_in_redirect_loop = false
        end

        redirect_to referrer && !is_self_redirect_loop && !is_sign_in_redirect_loop ? referrer : root_path,
            alert: "You are not authorized to perform this action."
      end
    end
  end
end
