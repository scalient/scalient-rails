# frozen_string_literal: true

# Copyright 2024 Roy Liu
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
  module Concurrent
    # A way to make any old collection class thread-safe and blocking with add- and take-style methods.
    module CollectionRetrofit
      extend ActiveSupport::Concern

      included do
        if !include?(::MonitorMixin)
          send(:include, ::MonitorMixin)
        end
      end

      # A monitor-owned condition variable composed with a (sortable) value.
      class ValueConditionVariable < ::MonitorMixin::ConditionVariable
        attr_reader :value

        def initialize(monitor, value)
          super(monitor)

          @value = value
        end

        def <=>(other)
          value <=> other.value
        end
      end

      # Adds items in a thread-safe manner that is synchronized with taker threads. The given block performs the actual
      # adding (e.g., `push` or `unshift`).
      def synchronized_add(&block)
        synchronize do
          result = block.call

          notify_takers

          result
        end
      end

      # Attempts to take exactly `n_items` from the collection with a potential timeout. The given block performs the
      # actual taking (e.g., `shift` or `take`) operation.
      def synchronized_take(n_items_argument = nil, timeout = nil, policy: :partial_on_timeout, &block)
        n_items = n_items_argument || 1
        start_time = Time.now.to_f

        n_requested_items = case policy
        when :partial_on_timeout, :all_or_nothing
          n_items
        when :partial
          1
        else
          raise ArgumentError, "Unrecognized policy #{policy}"
        end

        synchronize do
          if size >= n_items
            # If there happen to be `n_items`, just take and return.
            return block.call(n_items_argument ? n_items : nil)
          elsif policy == :partial && size > 0
            # Take whatever is there and return.
            return block.call(size)
          end

          vcv = ValueConditionVariable.new(@mon_data, n_requested_items)

          taker_priority_queue.push(vcv)

          loop do
            vcv.wait(timeout)

            if size >= n_items
              # Deregister the taker because we got `n_items`.
              taker_priority_queue.delete(vcv)

              # Take the `n_items` and return.
              return block.call(n_items_argument ? n_items : nil)
            elsif policy == :partial && size > 0
              # Deregister the taker because we got some items.
              taker_priority_queue.delete(vcv)

              # Take whatever is there and return.
              return block.call(size)
            else
              # If this taker isn't registered, reregister it because we came up empty-handed.
              if !taker_priority_queue.include?(vcv)
                taker_priority_queue.push(vcv)
              end

              if timeout
                current_time = Time.now.to_f

                if current_time - start_time >= timeout
                  if policy == :partial_on_timeout
                    if size > 0
                      # Take whatever is there and return.
                      return block.call(size)
                    else
                      # Return `nil` to indicate a timeout.
                      return nil
                    end
                  else
                    # Return `nil` to indicate a timeout.
                    return nil
                  end
                else
                  # Wait for the remaining timeout, in case of wakeup from other reasons.
                  timeout -= current_time - start_time
                end
              end
            end
          end
        end
      end

      # The priority queue of condition variables sorted by intended take amounts.
      def taker_priority_queue
        @taker_priority_queue ||= ::Concurrent::Collection::NonConcurrentPriorityQueue.new
      end

      # Notifies takers of potentially newly-added items.
      def notify_takers
        while (vcv = taker_priority_queue.peek) && vcv.value <= size
          taker_priority_queue.pop
          vcv.signal
        end
      end
    end
  end
end
