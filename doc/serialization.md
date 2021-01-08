### *Work in progress: Refrain from distribution.*

## Why serialization?

JSON serialization is probably a boring topic for many, but getting it wrong has serious implications, including, but
not limited to, data duplication, mismatched representations, overfetching, underfetching, and boilerplate
proliferation. For the purposes of this document, we refer to [JSON:API](https://jsonapi.org/) serialization, with a
focus on complex documents containing an extensive amount of interrelated resources.

**TODO**: Say more.

## Reluctant Serialization

We say that a serializer is reluctant if it only serializes associations when given some sort of indication by the user.
Since ActiveRecord is expressive and at the forefront of most Rails programmers' considerations, a natural definition of
reluctance is whether a given association is loaded: If it's not loaded, don't include its elements in the rendered
JSON:API document.

In the context of
the [`n + 1` loading problem](https://stackoverflow.com/questions/97197/what-is-the-n1-selects-problem-in-orm-object-relational-mapping)
, the above policy is a natural consequence. Consider the following serializer association:

```ruby

class UserSerializer < ActiveModel::Serializer
  has_many :users_organizations
end
```

Here the user (no pun intended) has no control over whether `users_organizations` are included in the document. If this
association happens to not be loaded, then database reads by ActiveRecord actually happen inside the serializer, which
is a kind of performance antipattern. To prevent the above situation, consider usage of reluctant serializers:

```ruby

class UserSerializer < ActiveModel::Serializer
  include Scalient::Serializer::Reluctant

  has_many_reluctant :users_organizations
end
```

The developer would have to declare, in the controller, their intention of including `users_organizations`, but the code
to do so *is the same code* used to prevent the `n + 1` loading problem:

```ruby
@user = User.where(id: params[:id]).includes(:users_organizations).first
```

As you can see, making use of reluctant serialization places no additional technical demands beyond using the
ActiveRecord ORM in a best practices way.

### Reluctant Updates

As it turns out, we can formulate a natural version of reluctant serialization for
[nested attribute](https://api.rubyonrails.org/v6.1.0/classes/ActiveRecord/NestedAttributes/ClassMethods.html)
assignment in the `update` action of API controllers. While you may recall that nested attributes are traditionally used
by server-rendered Rails forms via a combination of `fields_for` in the template and `accepts_nested_attributes_for` on
the model, (ab)using this system through a JSON-based API works extremely well! For an `update` action which may create,
update, or even destroy deeply nested associations, reading back all of the record's association may result in
overfetching, while reading back only the record itself potentially loses information, especially for newly created,
deeply nested associated records.

We can then formulate the policy for reluctant behavior under `update` as only serializing deeply nested associations
reached/touched/visited by nested attribute parameters. This way, the API user reads back what they need to *and no
more*.

### `belongs_to` Foreign Key Weak Linking

When a `belongs_to` association isn't preloaded on the record, reluctant behavior need not completely exclude the
association, because `belongs_to` reflections still contain potentially useful foreign key information. To this end, the
`belongs_to_reluctant` serializer association will include the foreign key (or the `(foreign_key, foreign_type)` tuple
if polymorphic) in the `attributes` section of the rendered JSON:API resource.

The above policy is particularly useful when the referenced object already exists in the ORM of some JavaScript library,
say Vuex ORM. By including just the foreign key of a record, the developer avoids overfetching while still updating the
foreign keys on the Vuex ORM analogue records, thus allowing Vuex ORM queries to pick up on the associations it needs
to, thus triggering Vue.js' reactivity system to update the end user's template.

### Usage

Here are the components to keep in mind when using the library.

* [`Scalient::Serializer::Reluctant`](../app/serializers/concerns/scalient/serializer/reluctant.rb) - A mixin that
  should be
  [included](https://github.com/scalient/scalient-rails/blob/main/spec/support/test_app/app/serializers/application_serializer.rb#L4)
  in serializers.
* [`Scalient::Serializer::NestedAttributesWatcher`](../app/serializers/concerns/scalient/serializer/nested_attributes_watcher.rb)
  &dash; A mixin that should be
  [included](https://github.com/scalient/scalient-rails/blob/main/spec/support/test_app/app/models/user.rb#L4)
  in models.
* [`ActiveModel::Serializer` monkey patch](../config/initializers/active_model_serializers.rb) &dash; Dasherizes foreign
  types of `belongs_to _, polymorphic: true` associations correctly and fixes an error with `nil` polymorphic values.
  You don't need to do anything other than `require "scalient-rails"`: The patch will automatically be applied as one of
  the engine's initializers.

Currently the library supports the syntax below.

* `reluctant_has_many` - The reluctant version of `ActiveModel::Serializer.has_many`.
* `reluctant_has_one` - The reluctant version of `ActiveModel::Serializer.has_one`.
* `reluctant_belongs_to` - The reluctant version of `ActiveModel::Serializer.belongs_to`. Foreign key weak linking will
  try to infer the reference class from the serializer name (e.g., `User` from `UserSerializer`) and use that to read
  foreign key information. If you'd like to customize the reference class, explicitly specify the `class_name` option.
  Note that the `polymorphic: true` option is supported and works as expected.

When in doubt, refer to the [unit tests](../spec/serializers/reluctant_serialization_spec.rb), which attempt to cover
reluctant behavior over various association types.
