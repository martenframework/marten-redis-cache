# Marten Redis Cache

[![CI](https://github.com/martenframework/marten-redis-cache/workflows/Specs/badge.svg)](https://github.com/martenframework/marten-redis-cache/actions)
[![CI](https://github.com/martenframework/marten-redis-cache/workflows/QA/badge.svg)](https://github.com/martenframework/marten-redis-cache/actions)

**Marten Redis Cache** provides a [Redis](https://redis.io) cache store that can be used with Marten web framework's [cache system](https://martenframework.com/docs/caching).

## Installation

Simply add the following entry to your project's `shard.yml`:

```yaml
dependencies:
  marten_redis_cache:
    github: martenframework/marten-redis-cache
```

And run `shards install` afterward.

## Configuration

First, add the following requirement to your project's `src/project.cr` file:

```crystal
require "marten_redis_cache"
```

Then you can configure your project to use the Redis cache store by setting the corresponding configuration option as follows:

```crystal
Marten.configure do |config|
  config.cache_store = MartenRedisCache::Store.new(uri: "redis:///")
end
```

The `uri` argument is optional: unless specified, the client will attempt to connect to Redis on `localhost` and port `6379`. It should be noted that this cache store also supports all the existing initialization options in addition to the `uri` argument (eg. `namespace`, `version`, `expires_in`, etc). Please refer to the [cache system documentation](https://martenframework.com/docs/caching) to learn more about Marten's caching framework.

## Authors

Morgan Aubert ([@ellmetha](https://github.com/ellmetha)) and 
[contributors](https://github.com/martenframework/marten-redis-cache/contributors).

## License

MIT. See ``LICENSE`` for more details.
