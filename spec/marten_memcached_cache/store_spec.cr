require "./spec_helper"

describe MartenRedisCache::Store do
  around_each do |t|
    Marten.cache.clear

    t.run

    Marten.cache.clear
  end

  describe "#clear" do
    it "clears all the items in the cache" do
      Marten.cache.write("foo", "bar")
      Marten.cache.write("xyz", "test")

      Marten.cache.clear

      Marten.cache.read("foo").should be_nil
      Marten.cache.read("xyz").should be_nil
    end

    it "clears only namespaced keys when the cache has an associated namespace" do
      store_with_namespace = MartenRedisCache::Store.new(uri: ENV_SETTINGS["REDIS_URI"].as(String), namespace: "ns")
      store_without_namespace = MartenRedisCache::Store.new(uri: ENV_SETTINGS["REDIS_URI"].as(String))

      store_with_namespace.write("foo", "bar")
      store_with_namespace.write("xyz", "test")
      store_without_namespace.write("foo", "bar")
      store_without_namespace.write("xyz", "test")

      store_with_namespace.clear

      store_with_namespace.read("foo").should be_nil
      store_with_namespace.read("xyz").should be_nil
      store_without_namespace.read("foo").should eq "bar"
      store_without_namespace.read("xyz").should eq "test"
    end
  end

  describe "#decrement" do
    it "can decrement an existing integer value" do
      2.times { Marten.cache.increment("foo") }

      Marten.cache.decrement("foo").should eq 1
      Marten.cache.read("foo", raw: true).try(&.to_i).should eq 1
    end

    it "can decrement an existing integer value when a namespace is used" do
      store = MartenRedisCache::Store.new(namespace: "ns", uri: ENV_SETTINGS["REDIS_URI"].as(String))
      2.times { store.increment("foo") }

      store.decrement("foo").should eq 1
      store.read("foo", raw: true).try(&.to_i).should eq 1
    end

    it "can decrement an existing integer value for a key that is not expired" do
      2.times { Marten.cache.increment("foo", expires_in: 2.hours) }

      Marten.cache.decrement("foo").should eq 1
      Marten.cache.read("foo", raw: true).try(&.to_i).should eq 1
    end

    it "can decrement an existing integer value by a specific amount" do
      5.times { Marten.cache.increment("foo") }

      Marten.cache.decrement("foo", amount: 3).should eq 2
      Marten.cache.read("foo", raw: true).try(&.to_i).should eq 2
    end

    it "decrements as expected in case the key does not exist" do
      Marten.cache.decrement("foo").should eq -1
      Marten.cache.read("foo", raw: true).try(&.to_i).should eq -1

      Marten.cache.decrement("bar", amount: 2).should eq -2
      Marten.cache.read("bar", raw: true).try(&.to_i).should eq -2
    end

    it "writes the amount value to the cache in case the key is expired" do
      5.times { Marten.cache.increment("foo", expires_in: 1.second) }
      5.times { Marten.cache.increment("bar", expires_in: 1.second) }

      sleep 2

      Marten.cache.decrement("foo").should eq -1
      Marten.cache.read("foo", raw: true).try(&.to_i).should eq -1

      Marten.cache.decrement("bar", amount: 2).should eq -2
      Marten.cache.read("bar", raw: true).try(&.to_i).should eq -2
    end
  end

  describe "#delete" do
    it "deletes the entry associated with the passed key and returns true" do
      Marten.cache.write("foo", "bar")

      Marten.cache.delete("foo").should be_true
      Marten.cache.exists?("foo").should be_false
    end

    it "returns false if the passed key is not in the cache" do
      Marten.cache.delete("foo").should be_false
    end
  end

  describe "#exists?" do
    it "returns true if the passed key is in the cache" do
      Marten.cache.write("foo", "bar")

      Marten.cache.exists?("foo").should be_true
    end

    it "returns false if the passed key is not in the cache" do
      Marten.cache.exists?("foo").should be_false
    end
  end

  describe "#increment" do
    it "can increment an existing integer value" do
      2.times { Marten.cache.increment("foo") }

      Marten.cache.increment("foo").should eq 3
      Marten.cache.read("foo", raw: true).try(&.to_i).should eq 3
    end

    it "can increment an existing integer value when a namespace is used" do
      store = MartenRedisCache::Store.new(namespace: "ns", uri: ENV_SETTINGS["REDIS_URI"].as(String))
      2.times { store.increment("foo") }

      store.increment("foo").should eq 3
      store.read("foo", raw: true).try(&.to_i).should eq 3
    end

    it "can increment an existing integer value for a key that is not expired" do
      2.times { Marten.cache.increment("foo", expires_in: 2.hours) }

      Marten.cache.increment("foo").should eq 3
      Marten.cache.read("foo", raw: true).try(&.to_i).should eq 3
    end

    it "can increment an existing integer value by a specific amount" do
      5.times { Marten.cache.increment("foo") }

      Marten.cache.increment("foo", amount: 3).should eq 8
      Marten.cache.read("foo", raw: true).try(&.to_i).should eq 8
    end

    it "increments as expected in case the key does not exist" do
      Marten.cache.increment("foo").should eq 1
      Marten.cache.read("foo", raw: true).try(&.to_i).should eq 1

      Marten.cache.increment("bar", amount: 2).should eq 2
      Marten.cache.read("bar", raw: true).try(&.to_i).should eq 2
    end

    it "writes the amount value to the cache in case the key is expired" do
      5.times { Marten.cache.increment("foo", expires_in: 1.second) }
      5.times { Marten.cache.increment("bar", expires_in: 1.second) }

      sleep 2

      Marten.cache.increment("foo").should eq 1
      Marten.cache.read("foo", raw: true).try(&.to_i).should eq 1

      Marten.cache.increment("bar", amount: 2).should eq 2
      Marten.cache.read("bar", raw: true).try(&.to_i).should eq 2
    end
  end

  describe "#read" do
    it "returns the cached value if there is one" do
      Marten.cache.write("foo", "bar")

      Marten.cache.read("foo").should eq "bar"
    end

    it "returns nil if the key does not exist" do
      Marten.cache.read("foo").should be_nil
    end
  end

  describe "#write" do
    it "write a store value as expected" do
      Marten.cache.write("foo", "bar")
      Marten.cache.read("foo").should eq "bar"
    end
  end
end
