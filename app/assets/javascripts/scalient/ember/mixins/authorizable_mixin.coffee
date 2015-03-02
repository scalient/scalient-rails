((factory) ->
  if typeof define is "function" and define.amd?
    define ["ember"], factory
).call(@, (Ember) ->
  AuthorizableMixin = Ember.Mixin.create
    authorize: (modelPromise) ->
      route = @

      Ember.RSVP.resolve(modelPromise).then(
        null,
        ((e) ->
          if e.status is 401
            route.transitionTo(route.get("authorizeRedirect"))
          else
            Ember.RSVP.reject("Unknown HTTP error status " + e.status)
        )
      )

      modelPromise

  AuthorizableMixin
)
