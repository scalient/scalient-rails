# frozen_string_literal: true

#
# Copyright 2015-2019 The Affective Computing Company
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

class OrganizationOwnershipPolicy
  POLICY_CLASS_NAME_PATTERN = Regexp.new("\\A(.*)Policy\\z")

  def self.inherited(klass)
    super

    target_class_name = POLICY_CLASS_NAME_PATTERN.match(klass.name)[1]
    target_class = target_class_name.safe_constantize
    target_param_key = target_class.model_name.param_key

    class << klass
      def through_association(*args)
        if args.size > 0
          @through_association = args.first
        else
          @through_association
        end
      end
    end

    # Alias `users` in the event that `target_class == User`.
    users_1 = User.arel_table.alias("users_1")

    # Alias `users_organizations` in the event that `authorization_class == UsersOrganization`.
    users_organizations_1 = UsersOrganization.arel_table.alias("users_organizations_1")

    organizations = Organization.arel_table.alias("organizations_1")

    targets = target_class.arel_table

    # The subquery targets table for `WHERE EXISTS`, deliberately renamed so that we can create a condition like
    # `WHERE targets.id = targets_1.id` inside of the subquery.
    targets_1 = targets.alias("targets_1")

    users_1_to_users_organizations_1_node =
      users_1.
        relation.
        join(users_organizations_1).
        on(users_1[:id].eq users_organizations_1[:user_id]).
        join_sources.first

    users_organizations_1_to_organizations_node =
      users_organizations_1.
        relation.
        join(organizations).
        on(users_organizations_1[:organization_id].eq organizations[:id]).
        join_sources.first

    organizations_to_users_organizations_1_node =
      organizations.
        relation.
        join(users_organizations_1).
        on(organizations[:id].eq users_organizations_1[:organization_id]).
        join_sources.first

    instance_methods = Module.new do
      define_method(:initialize_arel) do |join_param_keys|
        join_param_keys ||= []

        join_param_keys = [join_param_keys] \
          if !join_param_keys.is_a?(Array)

        join_tuples = join_param_keys.reverse.map do |join_param_key|
          through_class_name = join_param_key.to_s.camelize
          through_class = through_class_name.safe_constantize
          through_table_relation = through_class.arel_table
          through_table_alias = through_table_relation.alias("#{through_table_relation.name}_1")
          [through_class, through_table_relation, through_table_alias, "#{join_param_key}_id"]
        end.
          push([target_class, targets_1.relation, targets_1, "#{target_param_key}_id"])

        first_join_tuple = join_tuples.first
        first_join_class, first_join_table_relation, first_join_table_alias, first_association_id = first_join_tuple

        @organizations = organizations
        @targets = targets

        @authorizations = if first_join_class != User
          "Organizations#{first_join_class}".safe_constantize
        else
          UsersOrganization
        end.arel_table.alias("authorizations_1")

        @organizations_to_targets_nodes = [
          organizations.
            relation.
            join(@authorizations).
            on(organizations[:id].eq @authorizations[:organization_id]).
            join_sources.first,

          @authorizations.
            relation.
            join(first_join_table_alias).
            on(@authorizations[first_association_id].eq first_join_table_alias[:id]).
            join_sources.first
        ]

        join_tuples[1..-1].reduce(first_join_tuple) do |memo_tuple, join_tuple|
          _, memo_table_relation, memo_table_alias, memo_association_id = memo_tuple
          _, _, join_table_alias, = join_tuple

          @organizations_to_targets_nodes.push(
            memo_table_relation.
                join(join_table_alias).
                on(memo_table_alias[:id].eq join_table_alias[memo_association_id]).
                join_sources.first
          )

          join_tuple
        end

        @targets_to_organizations_nodes = [
          first_join_table_relation.
            join(@authorizations).
            on(first_join_table_alias[:id].eq @authorizations[first_association_id]).
            join_sources.first,

          @authorizations.
            relation.
            join(organizations).
            on(@authorizations[:organization_id].eq organizations[:id]).
            join_sources.first
        ]

        join_tuples.reverse[1..-1].reduce(join_tuples.last) do |memo_tuple, join_tuple|
          _, memo_table_relation, memo_table_alias, = memo_tuple
          _, _, join_table_alias, join_association_id = join_tuple

          @targets_to_organizations_nodes.unshift(
            memo_table_relation.
                join(join_table_alias).
                on(memo_table_alias[join_association_id].eq join_table_alias[:id]).
                join_sources.first
          )

          join_tuple
        end
      end

      attr_reader :organizations

      attr_reader :targets

      attr_reader :authorizations

      attr_reader :organizations_to_targets_nodes

      attr_reader :targets_to_organizations_nodes

      define_method(:create_scope) do
        return users_1 \
          if current_user.superadmin?

        # Is the user an admin for some organization?
        User.
          select(1).
          from(users_1).
          joins(users_1_to_users_organizations_1_node).
          where(
            (users_1[:id].eq current_user.id).
                and(users_organizations_1[:admin].eq true)
          ).
          order(users_1[:id]) # Prevent ActiveRecord from inserting its own `order` scope.
      end

      define_method(:update_scope) do
        return users_1 \
          if current_user.superadmin?

        object = send(target_param_key.to_sym)

        # Does the user own the target object through some organization?
        User.
          select(1).
          from(users_1).
          joins(
            users_1_to_users_organizations_1_node,
            users_organizations_1_to_organizations_node,
            *organizations_to_targets_nodes
          ).
          where(
            (users_1[:id].eq current_user.id).
                and(users_organizations_1[:admin].eq true).
                and(targets_1[:id].eq object.id)
          ).
          order(users_1[:id]) # Prevent ActiveRecord from inserting its own `order` scope.
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
    end

    klass.class_eval do
      include instance_methods

      define_method(:initialize) do |current_user, object|
        @current_user = current_user
        instance_variable_set("@#{target_param_key}".to_sym, object)

        initialize_arel(klass.through_association)
      end

      attr_reader :current_user
      attr_reader target_param_key.to_sym

      alias_method :authorized_index?, :authorized_create?
      alias_method :authorized_new?, :authorized_create?
      alias_method :authorized_show?, :authorized_update?
      alias_method :authorized_edit?, :authorized_update?
      alias_method :authorized_destroy?, :authorized_update?

      alias_method :index?, :authorized_index?
      alias_method :show?, :authorized_show?
      alias_method :new?, :authorized_new?
      alias_method :edit?, :authorized_edit?
      alias_method :create?, :authorized_create?
      alias_method :update?, :authorized_update?
      alias_method :destroy?, :authorized_destroy?

      scope_class = Class.new do
        include instance_methods

        attr_reader :current_user, :scope

        define_method(:initialize) do |current_user, scope|
          @current_user = current_user
          @scope = scope

          initialize_arel(klass.through_association)
        end

        define_method(:existence_subquery) do
          subquery =
            targets_1.
              relation.
              from.from(targets_1).
              project(1).
              where(targets[:id].eq targets_1[:id])

          [*targets_to_organizations_nodes, organizations_to_users_organizations_1_node].each do |node|
            subquery.join(node.left).on(node.right.expr)
          end

          subquery
        end

        define_method(:resolve_scope) do
          scope_to_working_organization = current_user.respond_to?(:working_users_organization) &&
            (working_users_organization_id = current_user.working_users_organization&.id)

          if current_user.superadmin?
            if !scope_to_working_organization
              scope.all
            else
              scope.where(existence_subquery.where(users_organizations_1[:id].eq working_users_organization_id).exists)
            end
          else
            subquery = existence_subquery.where((users_organizations_1[:admin].eq true))

            if !scope_to_working_organization
              subquery.where(users_organizations_1[:user_id].eq current_user.id)
            else
              subquery.where(users_organizations_1[:id].eq working_users_organization_id)
            end

            scope.where(subquery.exists)
          end
        end

        def resolve
          resolve_scope
        end
      end

      const_set("Scope", scope_class)
    end
  end
end
