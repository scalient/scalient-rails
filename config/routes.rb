# frozen_string_literal: true

# Copyright 2023 Scalient LLC
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

Scalient::Rails::Engine.routes.draw do
  id_any_pattern = Regexp.new("[^\\/]+")

  constraints(upload_id: id_any_pattern) do
    # Draw the Uppy Companion routes (see `https://uppy.io/docs/companion/`).
    post "/s3/multipart", to: "uppy_s3_multiparts#create"
    match "/s3/multipart", to: "uppy_s3_multiparts#preflight", via: :options
    get "/s3/multipart/:upload_id", to: "uppy_s3_multiparts#show"
    get "/s3/multipart/:upload_id/batch", to: "uppy_s3_multiparts#batch", as: "batch"
    match "/s3/multipart/:upload_id/:part_number", to: "uppy_s3_multiparts#preflight", via: :options
    get "/s3/multipart/:upload_id/:part_number", to: "uppy_s3_multiparts#part_number", as: "part_number"
    post "/s3/multipart/:upload_id/complete", to: "uppy_s3_multiparts#complete", as: "complete"
    delete "/s3/multipart/:upload_id", to: "uppy_s3_multiparts#destroy"
  end
end
