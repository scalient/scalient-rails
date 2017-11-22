import * as Ember from "ember";
import "ember-data";

var application = Ember.Application.create({
    LOG_TRANSITIONS: true
});

application.deferReadiness();

export {application as default, application};
