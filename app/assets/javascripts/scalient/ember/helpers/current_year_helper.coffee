((factory) ->
  if typeof define is "function" and define.amd?
    define ["ember",
            "../application-base"], factory
).call(@, (Ember, #
           app) ->
  Ember.Handlebars.helper("currentYear", (value, options) ->
    new Date().getFullYear()
  )

  app
)
