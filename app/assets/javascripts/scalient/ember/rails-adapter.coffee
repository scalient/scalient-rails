((factory) ->
  if typeof define is "function" and define.amd?
    define ["ember",
            "./application-base"], factory
).call(@, (Ember, #
           app) ->
  app.ApplicationAdapter = DS.ActiveModelAdapter.extend
    namespace: "api"

  app.ApplicationSerializer = DS.ActiveModelSerializer

  app
)
