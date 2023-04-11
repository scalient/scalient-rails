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
    module SessionSecurity
      extend ActiveSupport::Concern

      included do
        if include?(::Devise::Models::Recoverable && ::Devise::Models::JwtAuthenticatable)
          include RecoverableAndJwtAuthenticatable
        end

        if include?(::Devise::Models::Authenticatable && ::Devise::JWT::RevocationStrategies::JTIMatcher)
          include AuthenticatableAndJtiMatcher
        end
      end

      module RecoverableAndJwtAuthenticatable
        extend ActiveSupport::Concern

        module ClassMethods
          # Password resets should also result in the revocation of the JWT.
          def reset_password_by_token(attributes = {})
            user = super

            revoke_jwt(nil, user)

            user
          end
        end
      end

      module AuthenticatableAndJtiMatcher
        extend ActiveSupport::Concern

        # We can conveniently use the jti claim as a way to salt the session state further and effectively invalidate
        # the session cookie as a side effect of the jti changing to signify JWT revocation on user session destruction.
        # Inspired by `https://makandracards.com/makandra/53562-devise-invalidating-all-sessions-for-a-user`.
        def authenticatable_salt
          "#{super}#{jti}"
        end
      end
    end
  end
end
