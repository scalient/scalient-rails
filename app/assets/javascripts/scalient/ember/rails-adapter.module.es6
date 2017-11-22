import * as Ember from "ember";
import * as DS from "scalient/ember/derequire!ember-data";
import "active-model-adapter";
import application from "./application-base";
import CsrfMixin from "./mixins/csrf_mixin";

application.ApplicationAdapter = DS.ActiveModelAdapter.extend({
    namespace: "api"
});

application.ApplicationSerializer = DS.ActiveModelSerializer;

Ember.$(() => {
    application.set("csrfToken", Ember.$("meta[name=\"csrf-token\"]").attr("content"));
    application.reopen(CsrfMixin);

    Ember.$.ajaxPrefilter((options, originalOptions, xhr) => {
        xhr.setRequestHeader("X-CSRF-Token", application.get("csrfToken"));
    });
});

export {application as default, application};
