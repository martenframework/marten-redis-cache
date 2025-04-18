module MartenRedisCache
  # A cache store implementation that stores data in Redis.
  #
  # The `uri` argument is optional: unless specified, the client will attempt to connect to Redis on `localhost` and
  # port `6379`. It should be noted that this cache store also supports all the existing initialization options in
  # addition to the `uri` argument (eg. `namespace`, `version`, `expires_in`, etc).
  class Store < Marten::Cache::Store::Base
    def initialize(
      @namespace : String? = nil,
      @expires_in : Time::Span? = nil,
      @version : Int32? = nil,
      @compress = true,
      @compress_threshold = Marten::Cache::Store::Base::DEFAULT_COMPRESS_THRESHOLD,
      uri : String? = nil,
    )
      super(@namespace, @expires_in, @version, @compress, @compress_threshold)

      @client = !uri.nil? ? Redis::Client.new(URI.parse(uri)) : Redis::Client.new
    end

    # The amount of work that should be done to retrieve elements when using SCAN.
    private SCAN_COUNT = 1000

    private getter client

    def clear : Nil
      namespace ? delete_namespaced_keys : client.flushdb
    end

    def decrement(
      key : String,
      amount : Int32 = 1,
      expires_at : Time? = nil,
      expires_in : Time::Span? = nil,
      version : Int32? = nil,
      race_condition_ttl : Time::Span? = nil,
      compress : Bool? = nil,
      compress_threshold : Int32? = nil,
    ) : Int
      normalized_key = normalize_key(key.to_s)

      effective_expires_in = if !expires_at.nil?
                               expires_at.to_utc - Time.utc
                             else
                               expires_in.nil? ? self.expires_in : expires_in
                             end

      effective_expires_in = adapt_expiry_for_race_condition(effective_expires_in, race_condition_ttl)

      client.decrby(normalized_key, amount).tap do
        client.expire(normalized_key, effective_expires_in.not_nil!.total_seconds.to_i) if effective_expires_in
      end
    end

    def delete_entry(key : String) : Bool
      client.del(key) == 1_i64
    end

    def increment(
      key : String,
      amount : Int32 = 1,
      expires_at : Time? = nil,
      expires_in : Time::Span? = nil,
      version : Int32? = nil,
      race_condition_ttl : Time::Span? = nil,
      compress : Bool? = nil,
      compress_threshold : Int32? = nil,
    ) : Int
      normalized_key = normalize_key(key.to_s)

      effective_expires_in = if !expires_at.nil?
                               expires_at.to_utc - Time.utc
                             else
                               expires_in.nil? ? self.expires_in : expires_in
                             end

      effective_expires_in = adapt_expiry_for_race_condition(effective_expires_in, race_condition_ttl)

      client.incrby(normalized_key, amount).tap do
        client.expire(normalized_key, effective_expires_in.not_nil!.total_seconds.to_i) if effective_expires_in
      end
    end

    def read_entry(key : String) : String?
      client.get(key)
    end

    def write_entry(
      key : String,
      value : String,
      expires_in : Time::Span? = nil,
      race_condition_ttl : Time::Span? = nil,
    )
      # Add an extra 5 minutes to the expiry of the Redis entry to allow for race condition TTL reads.
      if !expires_in.nil? && !race_condition_ttl.nil?
        expires_in += 5.minutes
      end

      client.set(key, value, ex: expires_in.try(&.total_seconds.to_i))
      true
    end

    private def adapt_expiry_for_race_condition(expires_in : Time::Span? = nil, race_condition_ttl : Time::Span? = nil)
      # Add an extra 5 minutes to the expiry of the memcached entry to allow for race condition TTL reads.
      if !expires_in.nil? && !race_condition_ttl.nil?
        expires_in += 5.minutes
      end

      expires_in
    end

    private def delete_namespaced_keys
      parent = normalize_key("*") # Will return something like "namespace:*"
      cursor = "0"

      loop do
        # Progressively retrieve keys using SCAN (and the COUNT option), and delete them.
        cursor, keys = client.scan(cursor.to_s, match: parent, count: SCAN_COUNT).as(Array(Redis::Value))
        client.del(keys.as(Array(Redis::Value)).map(&.to_s))

        break if cursor.to_s == "0"
      end
    end
  end
end
