module EasyML
  module Support
    module Lockable
      KEYS_HASH = "easy_ml:lock_keys"

      def self.query
        Rails.cache.read(KEYS_HASH) || {}
      end

      def self.wipe
        keys = query.keys
        Rails.cache.delete_multi(keys)
        Rails.cache.delete(KEYS_HASH)
      end

      def self.with_lock_client(key, wait_timeout: 0.1, stale_timeout: 60 * 10, resources: 1)
        prefixed_key = "easy_ml:#{key}"

        # Track the key
        current_keys = query
        current_keys[prefixed_key] = Time.current
        Rails.cache.write(KEYS_HASH, current_keys)

        client = Suo::Client::Redis.new(prefixed_key, {
          acquisition_lock: wait_timeout,
          stale_lock: stale_timeout,
          resources: resources,
          client: client,
        })

        begin
          lock_key = client.lock
          if lock_key
            yield client
          end
        ensure
          client.unlock(lock_key)
        end
      end

      def client
        return @client if @client

        host = ENV["REDIS_HOST"] || Resque.redis.client.host
        @client = Redis.new(host: host)
      end
    end
  end
end
