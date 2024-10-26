# frozen_string_literal: true

class ConcurrentArray < Array
  include Scalient::Concurrent::CollectionRetrofit

  def s_push(*items)
    synchronized_add do
      push(*items)
    end
  end

  def s_shift(n_items, timeout = nil, policy: :partial_on_timeout)
    synchronized_take(n_items, timeout, policy:) do |n_taken_items|
      shift(n_taken_items)
    end
  end
end
