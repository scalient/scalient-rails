# frozen_string_literal: true
#
# Copyright 2015 The Affective Computing Company
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

class OrganizationAuthorizationPolicy
  POLICY_CLASS_NAME_PATTERN = Regexp.new("\\A(.*)Policy\\z")
  TARGET_CLASS_NAME_PATTERN = Regexp.new("\\A(?:Organizations(.*)|(.*)Organization)\\z")

  def self.inherited(klass)
    super

    authorization_class_name = POLICY_CLASS_NAME_PATTERN.match(klass.name)[1]
    authorization_class = authorization_class_name.safe_constantize
    authorization_param_key = authorization_class.model_name.param_key

    m = TARGET_CLASS_NAME_PATTERN.match(authorization_class_name)

    if m[1]
      # Example: `OrganizationsExperience`.
      target_class = m[1].safe_constantize
    elsif m[2]
      # Example: `UsersOrganization`.
      target_class = m[2].singularize.safe_constantize
    else
      "Invalid authorization class #{authorization_class_name.dump}"
    end

    target_param_key = target_class.model_name.singular

    # Alias `users` in the event that `target_class == User`.
    users_1 = User.arel_table.alias("users_1")

    # Alias `users_organizations` in the event that `authorization_class == UsersOrganization`.
    users_organizations_1 = UsersOrganization.arel_table.alias("users_organizations_1")
    users_organizations_2 = UsersOrganization.arel_table.alias("users_organizations_2")

    organizations_1 = Organization.arel_table.alias("organizations_1")
    authorizations_1 = authorization_class.arel_table.alias("authorizations_1")
    targets_1 = target_class.arel_table.alias("targets_1")

    users_1_to_users_organizations_1_node =
        users_1
            .relation
            .join(users_organizations_1)
            .on(users_1[:id].eq users_organizations_1[:user_id])
            .join_sources.first

    users_organizations_1_to_organizations_1_node =
        users_organizations_1
            .relation
            .join(organizations_1)
            .on(users_organizations_1[:organization_id].eq organizations_1[:id])
            .join_sources.first

    organizations_1_to_authorizations_1_node =
        organizations_1
            .relation
            .join(authorizations_1)
            .on(organizations_1[:id].eq authorizations_1[:organization_id])
            .join_sources.first

    authorizations_1_to_targets_1_node =
        authorizations_1
            .relation
            .join(targets_1)
            .on(authorizations_1["#{target_param_key}_id".to_sym].eq targets_1[:id])
            .join_sources.first

    users_1_to_users_organizations_2_node =
        users_1
            .relation
            .join(users_organizations_2)
            .on(users_1[:id].eq users_organizations_2[:user_id])
            .join_sources.first

    organizations_1_to_users_organizations_1_node =
        organizations_1
            .relation
            .join(users_organizations_1)
            .on(organizations_1[:id].eq users_organizations_1[:organization_id])
            .join_sources.first

    instance_methods = Module.new do
      define_method(:create_scope) do
        return users_1 \
          if current_user.superadmin?

        authorization = send(authorization_param_key.to_sym)

        # Does the user already own the target object through some organization?
        User
            .select(users_1[Arel.star])
            .from(users_1)
            .joins(
                # These joins detect ownership through some organization.
                users_1_to_users_organizations_1_node,
                users_organizations_1_to_organizations_1_node,
                organizations_1_to_authorizations_1_node,
                authorizations_1_to_targets_1_node,
                # This join checks that the user is an admin for the authorization's organization.
                users_1_to_users_organizations_2_node
            )
            .where(
                (users_1[:id].eq current_user.id)
                    .and(
                        authorizations_1["#{target_param_key}_id".to_sym]
                            .eq authorization.send(target_param_key.to_sym).id
                    )
                    .and(users_organizations_2[:admin].eq true)
                    .and(users_organizations_2[:organization_id].eq authorization.organization.id)
            )
            .order(users_1[:id])
      end

      define_method(:update_scope) do
        return users_1 \
          if current_user.superadmin?

        authorization = send(authorization_param_key.to_sym)

        # Does the user own the target object through the authorization?
        User
            .select(users_1[Arel.star])
            .from(users_1)
            .joins(users_1_to_users_organizations_1_node)
            .where(
                (users_1[:id].eq current_user.id)
                    .and(users_organizations_1[:admin].eq true)
                    .and(users_organizations_1[:organization_id].eq authorization.organization.id)
            )
            .order(users_1[:id])
      end

      define_method(:authorized_create?) do
        return true \
          if current_user.superadmin?

        !!create_scope.first
      end

      define_method(:authorized_update?) do
        return true \
          if current_user.superadmin?

        !!update_scope.first
      end

      define_method(:authorizations) do
        authorizations_1
      end

      define_method(:targets) do
        targets_1
      end
    end

    klass.class_eval do
      include instance_methods

      define_method(:initialize) do |current_user, authorization|
        @current_user = current_user
        instance_variable_set("@#{authorization_param_key}".to_sym, authorization)
      end

      attr_reader :current_user
      attr_reader authorization_param_key.to_sym

      # Newly created objects can use the `authorized_update?` logic.
      alias_method "authorized_create_with_new_#{target_param_key}?".to_sym, :authorized_update?

      alias_method :authorized_destroy?, :authorized_update?

      alias_method :create?, :authorized_create?
      alias_method "create_with_new_#{target_param_key}?".to_sym,
                   "authorized_create_with_new_#{target_param_key}?".to_sym
      alias_method :update?, :authorized_update?
      alias_method :destroy?, :authorized_destroy?

      scope_class = Class.new do
        attr_reader :current_user, :scope

        def initialize(current_user, scope)
          @current_user = current_user
          @scope = scope
        end

        define_method(:resolve_scope) do
          return scope \
            if current_user.superadmin?

          authorizations = scope.arel_table

          authorizations_to_organizations_node =
              authorizations
                  .join(organizations_1)
                  .on(authorizations[:organization_id].eq organizations_1[:id])
                  .join_sources.first

          # Get all authorizations joined with organizations that the user is an admin for.
          scope
              .joins(
                  authorizations_to_organizations_node,
                  organizations_1_to_users_organizations_1_node
              )
              .where(
                  (users_organizations_1[:user_id].eq current_user.id)
                      .and(users_organizations_1[:admin].eq true)
              )
        end

        def resolve
          resolve_scope
        end
      end

      const_set("Scope", scope_class)
    end
  end
end
