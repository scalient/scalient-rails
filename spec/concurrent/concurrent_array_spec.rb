# frozen_string_literal: true

require "spec_helper"

describe Scalient::Concurrent::CollectionRetrofit do
  it "performs synchronized `shift` with different policies" do
    shared_queue_1 = ConcurrentArray.new
    shared_queue_2 = ConcurrentArray.new
    shared_queue_3 = ConcurrentArray.new
    shared_queue_4 = ConcurrentArray.new
    shared_queue_5 = ConcurrentArray.new
    items_1 = nil
    items_2 = []
    items_3 = nil
    items_4 = nil
    items_5 = []

    sender_1 = Thread.new do
      sleep(0.1)

      (0...5).each do |i|
        shared_queue_1.s_push(i)
        sleep(0.1)
      end
    end

    receiver_1 = Thread.new do
      sleep(0.1)

      items_1 = shared_queue_1.s_shift(5, 0.25, policy: :partial_on_timeout)
    end

    sender_2 = Thread.new do
      sleep(0.1)

      (0...5).each do |i|
        shared_queue_2.s_push(i)
        sleep(0.1)
      end
    end

    receiver_2 = Thread.new do
      sleep(0.1)

      while (items = shared_queue_2.s_shift(5, 0.15, policy: :partial))
        items_2.concat(items)
      end
    end

    sender_3 = Thread.new do
      sleep(0.1)

      (0...5).each do |i|
        shared_queue_3.s_push(i)
        sleep(0.1)
      end
    end

    receiver_3 = Thread.new do
      sleep(0.1)

      items_3 = shared_queue_3.s_shift(5, 0.25, policy: :all_or_nothing)
    end

    sender_4 = Thread.new do
      sleep(0.1)

      (0...5).each do |i|
        shared_queue_4.s_push(i)
        sleep(0.1)
      end
    end

    receiver_4 = Thread.new do
      sleep(0.1)

      items_4 = shared_queue_4.s_shift(5, 0.55, policy: :all_or_nothing)
    end

    sender_5 = Thread.new do
      sleep(0.1)

      (0...5).each do |i|
        shared_queue_5.s_push(i)
        sleep(0.1)
      end
    end

    receiver_5 = Thread.new do
      sleep(0.1)

      while (item = shared_queue_5.s_shift(nil, 0.15))
        items_5.push(item)
      end
    end

    sender_1.join
    receiver_1.join
    sender_2.join
    receiver_2.join
    sender_3.join
    receiver_3.join
    sender_4.join
    receiver_4.join
    sender_5.join
    receiver_5.join

    expect(items_1).to eq([0, 1, 2])
    expect(items_2).to eq([0, 1, 2, 3, 4])
    expect(items_3).to eq(nil)
    expect(items_4).to eq([0, 1, 2, 3, 4])
    expect(items_5).to eq([0, 1, 2, 3, 4])
  end
end
