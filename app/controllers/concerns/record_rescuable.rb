# frozen_string_literal: true
#
# Copyright 2014 Roy Liu
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

module RecordRescuable
  extend ActiveSupport::Concern

  included do
    attr_accessor :error_record

    helper_method :error_record
    helper_method :errors

    def record(&block)
      raise "Please provide a block for \"record_begin\"" if block.nil?

      Configuration.new(self, block)
    end

    def errors
      !@error_record.nil? ? @error_record.errors : ActiveModel::Errors.new(nil)
    end
  end

  class Configuration
    def initialize(context, block)
      @context = context
      @block = block
    end

    def rescue(&rescue_block)
      raise "Please provide a block for \"record_rescue\"" if rescue_block.nil?

      @rescue_block = rescue_block

      self
    end

    def ensure(&ensure_block)
      raise "Please provide a block for \"record_ensure\"" if ensure_block.nil?

      @ensure_block = ensure_block

      self
    end

    def run
      begin
        @context.instance_exec(&@block)
      rescue ActiveRecord::RecordInvalid => e
        @context.error_record = e.record
        @context.instance_exec(e, &@rescue_block) if !@rescue_block.nil?
      ensure
        @context.instance_exec(&@ensure_block) if !@ensure_block.nil?
      end
    end
  end
end
