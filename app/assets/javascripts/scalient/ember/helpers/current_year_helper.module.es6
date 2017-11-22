import * as Ember from "ember";
import {application} from "../application-base";

Ember.Handlebars.helper("currentYear", (value, options) => {
    new Date().getFullYear();
});

export {application as default, application};
