module EasyML
  class BatchJob
    extend Resque::Plugins::BatchedJob
    @queue = :easy_ml

    class << self
      # Default or dynamically generated batch ID
      def default_batch_id
        "batch_#{name}_#{SecureRandom.uuid}"
      end

      # E.g. EasyML::ComputeFeatureBatchJob.enqueue_batch(features.map(&:id))
      #
      def enqueue_batch(args_list, batch_id = default_batch_id)
        args_list = args_list.map { |arg| arg.is_a?(Array) ? arg : [arg] }
        store_batch_arguments(batch_id, args_list)

        args_list.each do |args|
          Resque.enqueue_batched_job(self, batch_id, *args)
        end

        batch_id
      end

      private

      # Store batch arguments in Redis
      def store_batch_arguments(batch_id, args_list)
        redis_key = "#{batch(batch_id)}:original_args"
        redis.set(redis_key, Resque.encode(args_list))
      end

      # Fetch batch arguments from Redis
      def fetch_batch_arguments(batch_id)
        redis_key = "#{batch(batch_id)}:original_args"
        stored_args = redis.get(redis_key)
        stored_args ? Resque.decode(stored_args) : []
      end

      # Redis instance for storing batch arguments
      def redis
        Resque.redis
      end
    end
  end
end
