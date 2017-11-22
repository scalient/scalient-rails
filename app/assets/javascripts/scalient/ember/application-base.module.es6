import * as Ember from "ember";

var application = Ember.Application.create({
    LOG_TRANSITIONS: true
});

application.deferReadiness();

export {application as default, application};
