module EasyML
  module Support
    module Lockable
      KEYS_HASH = "easy_ml:lock_keys"

      # Fetch all tracked keys from the Redis hash
      def self.query
        client.hgetall(KEYS_HASH) || {}
      end

      # Delete all tracked keys and wipe the hash
      def self.wipe
        keys = query.keys
        keys.each { |key| client.del(key) } # Delete individual keys
        client.del(KEYS_HASH) # Delete the KEYS_HASH
      end

      # Execute a block with a Redis lock
      def self.with_lock_client(key, wait_timeout: 0.1, stale_timeout: 60 * 10, resources: 1)
        prefixed_key = "easy_ml:#{key}"

        # Track the key
        track_key(prefixed_key)

        suo_client = Suo::Client::Redis.new(prefixed_key, {
          acquisition_timeout: wait_timeout,
          stale_lock_expiry: stale_timeout,
          resources: resources,
          client: client,
        })

        lock_key = nil
        begin
          lock_key = suo_client.lock
          if lock_key
            track_lock(prefixed_key, lock_key)
            yield suo_client
          end
        ensure
          suo_client.unlock(lock_key) if lock_key
          track_unlock(prefixed_key)
        end
      end

      def self.track_lock(prefixed_key, lock_key)
        client.hset(KEYS_HASH, prefixed_key, lock_key)
      end

      # Track a new key in the KEYS_HASH
      def self.track_key(prefixed_key)
        unless query.key?(prefixed_key)
          client.hset(KEYS_HASH, prefixed_key, Time.current.to_s)
        end
      end

      def self.track_unlock(prefixed_key)
        client.hdel(KEYS_HASH, prefixed_key)
      end

      # Redis client
      def self.client
        @client ||= Redis.new(host: redis_host)
      end

      # Determine Redis host
      def self.redis_host
        ENV["REDIS_HOST"] || (defined?(Resque) ? Resque.redis.client.host : "localhost")
      end
    end
  end
end
