((factory) ->
  if typeof define is "function" and define.amd?
    define ["ember",
            "./application-base",
            "./mixins/csrf_mixin"], factory
).call(@, (Ember, #
           app, #
           CsrfMixin) ->
  app.ApplicationAdapter = DS.ActiveModelAdapter.extend
    namespace: "api"

  app.ApplicationSerializer = DS.ActiveModelSerializer

  Ember.$ ->
    app.set("csrfToken", Ember.$("meta[name=\"csrf-token\"]").attr("content"))
    app.reopen(CsrfMixin)

    Ember.$.ajaxPrefilter (options, originalOptions, xhr) ->
      xhr.setRequestHeader("X-CSRF-Token", app.get("csrfToken"))

  app
)
