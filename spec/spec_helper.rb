# frozen_string_literal: true
#
# Copyright 2019-2020 The Affective Computing Company
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

require "pathname"

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rspec/rails"

Pathname.glob("spec/support/*.rb").each { |f| require f.realpath.to_s }

ActiveRecord::Migration.maintain_test_schema!

RSpec.configure do |config|
  # If you're not using ActiveRecord, or you'd prefer not to run each of your examples within a transaction, remove the
  # following line or assign false instead of true.
  config.use_transactional_fixtures = true

  # RSpec Rails can automatically mix in different behaviours to your tests based on their file location, for example
  # enabling you to call `get` and `post` in specs under `spec/controllers`.
  config.infer_spec_type_from_file_location!

  # Filter lines from Rails gems in backtraces.
  config.filter_rails_from_backtrace!

  # Run specs in random order to surface order dependencies. If you find an order dependency and want to debug it, you
  # can fix the order by providing the seed, which is printed after each run.
  #
  #     --seed 1234
  config.order = "random"

  # Use color.
  config.color = true

  # Use the given formatter.
  config.formatter = :documentation
end
