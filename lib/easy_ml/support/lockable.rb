module EasyML
  module Support
    module Lockable
      KEYS_HASH = "easy_ml:lock_keys"

      def self.unlock!(key)
        suo_client = lock_client(key)

        suo_client.locks.map(&:last).each do |lock_key|
          suo_client.unlock(lock_key)
        end
      end

      def self.locked?(key)
        suo_client = lock_client(key)
        suo_client.locked?
      end

      def self.locks(key)
        suo_client = lock_client(key)
        suo_client.locks
      end

      def self.lock_client(key, wait_timeout: 0.1, stale_timeout: 60 * 10, resources: 1)
        Suo::Client::Redis.new(key, {
          acquisition_timeout: wait_timeout,
          stale_lock_expiry: stale_timeout,
          resources: resources,
          client: client,
        })
      end

      # Execute a block with a Redis lock
      def self.with_lock(key, wait_timeout: 0.1, stale_timeout: 60 * 10, resources: 1)
        lock_key = nil
        suo_client = lock_client(key, wait_timeout: wait_timeout, stale_timeout: stale_timeout, resources: resources)
        begin
          lock_key = suo_client.lock
          if lock_key
            yield suo_client
          end
        ensure
          suo_client.unlock(lock_key) if lock_key
        end
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
