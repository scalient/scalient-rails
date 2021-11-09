# frozen_string_literal: true

#
# Copyright 2021 Scalient LLC
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not
# use this file except in compliance with the License. You may obtain a copy of
# the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations under
# the License.

require "action_dispatch/http/mime_negotiation"

# We monkey patch the Rails MIME content negotiator to not take the `BROWSER_LIKE_ACCEPTS` shortcut:
# https://www.bigbinary.com/blog/mime-type-resolution-in-rails#case-1-http-accept-is. There has been much written about
# this issue:
#   * "Multiple accept headers' specificity is misinterpreted" - https://github.com/rails/rails/issues/9940.
#   * "Fix broken Accept header parsing and content negotiation" - https://github.com/rails/rails/pull/14540.
#   * The monkey patch itself - https://github.com/rails/rails/issues/9940#issuecomment-374936185.
#
# This resolves strange behavior like the axios HTTP library receiving an HTML response from some Rails controller's
# `respond_to` block just because it includes `*/*` in `Accept`:
# https://github.com/axios/axios/blob/dbc634c/lib/defaults.js#L105-L109.
ActionDispatch::Http::MimeNegotiation.send(:remove_const, :BROWSER_LIKE_ACCEPTS)
ActionDispatch::Http::MimeNegotiation.const_set(:BROWSER_LIKE_ACCEPTS, Regexp.new("\\A🤮\\z"))
