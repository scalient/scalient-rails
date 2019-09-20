((factory) ->
  if typeof define is "function" and define.amd?
    define ["ember",
            "ember-data"], factory
).call(@, (Ember, #
           DS) ->
  app = Ember.Application.create
    LOG_TRANSITIONS: true

  app.deferReadiness()

  app
)
