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
