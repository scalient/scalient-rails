((factory) ->
  if typeof define is "function" and define.amd?
    define ["ember"], factory
).call(@, (Ember) ->
  CsrfMixin = Ember.Mixin.create
    csrfTokenObserver: (->
      Ember.$("meta[name=\"csrf-token\"]").attr("content", @get("csrfToken"))
    ).observes("csrfToken")

  CsrfMixin
)
