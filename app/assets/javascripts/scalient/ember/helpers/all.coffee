((factory) ->
  if typeof define is "function" and define.amd?
    define ["../application-base",
            "./current_year_helper"], factory
).call(@, (app, #
           CurrentYearHelper) ->
  app
)
