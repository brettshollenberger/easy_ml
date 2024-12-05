module EasyML
  module Support
    module Lockable
      def self.with_lock_client(key, wait_timeout: 0.1, stale_timeout: 60 * 10, resources: 1)
        client = Suo::Client::Redis.new(key, {
                                          acquisition_lock: wait_timeout,
                                          stale_lock_expiration: stale_timeout,
                                          resources: resources,
                                          client: Sidekiq.redis(&:itself)
                                        })
        yield client
      end
    end
  end
end
