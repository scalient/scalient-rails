# frozen_string_literal: true

# Copyright 2024 Scalient LLC
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

module Scalient
  module Daemonizable
    def _status
      @_status ||= :stopped
    end

    def _status=(_status)
      @_status = _status
    end

    def _monitor
      @_monitor ||= Monitor.new
    end

    def _termination_promises
      @_termination_promises ||= []
    end

    def synchronized(&)
      _monitor.synchronize(&)
    end

    def start_service
      raise NotImplementedError, "This method is abstract"
    end

    def stop_service
      raise NotImplementedError, "This method is abstract"
    end

    def on_service_stop(exception = nil, result = nil)
      synchronized do
        if exception
          _termination_promises.each do |termination_promise|
            termination_promise.fail(exception)
          end
        else
          _termination_promises.each do |termination_promise|
            termination_promise.set(result)
          end
        end

        _termination_promises.clear

        self._status = :stopped
      end
    end

    def daemonize
      synchronized do
        if _status == :stopped
          termination_promise = ::Concurrent::Promise.new
          _termination_promises.push(termination_promise)

          start_service

          self._status = :running

          termination_promise
        else
          ::Concurrent::Promise.fulfill(nil)
        end
      end
    end

    def stop
      synchronized do
        stop_service
      end
    end
  end
end
