import * as Ember from "ember";

var CsrfMixin = Ember.Mixin.create({
    csrfTokenObserver: function () {
        Ember.$("meta[name=\"csrf-token\"]").attr("content", this.get("csrfToken"));
    }.observes("csrfToken")
});

export {CsrfMixin as default, CsrfMixin};
