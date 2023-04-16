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
      uri : String? = nil
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

    private def delete_entry(key : String) : Bool
      client.del(key) == 1_i64
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

    private def read_entry(key : String) : Marten::Cache::Entry?
      deserialize_entry(client.get(key))
    end

    private def write_entry(
      key : String,
      entry : Marten::Cache::Entry,
      expires_in : Time::Span? = nil,
      race_condition_ttl : Time::Span? = nil,
      compress : Bool? = nil,
      compress_threshold : Int32? = nil
    )
      serialized_entry = serialize_entry(entry, compress, compress_threshold)

      # Add an extra 5 minutes to the expiry of the Redis entry to allow for race condition TTL reads.
      if !expires_in.nil? && !race_condition_ttl.nil?
        expires_in += 5.minutes
      end

      client.set(key, serialized_entry, expires_in.try(&.total_seconds.to_i))
      true
    end
  end
end
