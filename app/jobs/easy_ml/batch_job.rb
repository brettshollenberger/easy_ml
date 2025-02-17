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
        args_list = args_list.map do |arg|
          arg = arg.is_a?(Array) ? arg : [arg]
          arg.map do |arg|
            arg.merge!(
              batch_id: batch_id,
            )
          end
        end
        store_batch_arguments(batch_id, args_list)

        args_list.each do |args|
          Resque.enqueue_batched_job(self, batch_id, *args)
        end

        batch_id
      end

      def enqueue_ordered_batches(args_list)
        parent_id = get_parent_batch_id(args_list)
        store_batch_arguments(parent_id, args_list)

        batch = args_list.first
        rest = args_list[1..]

        rest.map do |batch|
          Resque.redis.rpush("batch:#{parent_id}:remaining", batch.to_json)
        end
        track_batch(parent_id)
        handle_batch(parent_id, batch)
      end

      def handle_batch(parent_id, batch)
        if batch.size > 1
          enqueue_batch(batch, parent_id)
        else
          new.perform(parent_id, batch.first)
          after_batch_hook(parent_id, batch)
        end
      end

      def enqueue_next_batch(caller, parent_id)
        next_batch = Resque.redis.lpop("batch:#{parent_id}:remaining")
        payload = Resque.decode(next_batch)

        caller.handle_batch(parent_id, payload)
      end

      def next_batch?(parent_id)
        (batches_remaining(parent_id) > 0)
      end

      def list_batches
        Resque.redis.hkeys("batches:tracking")
      end

      def track_batch(parent_id)
        Resque.redis.hset("batches:tracking", parent_id, true)
      end

      def cleanup_all
        list_batches.each do |batch_id|
          cleanup_batch(batch_id)
        end
      end

      def batches_remaining(parent_id)
        Resque.redis.llen("batch:#{parent_id}:remaining")
      end

      def cleanup_batch(parent_id)
        Resque.redis.del("batch:#{parent_id}:remaining")
        Resque.redis.hdel("batches:tracking", parent_id)
      end

      def batch_args
        list_batches.map do |batch_id|
          fetch_batch_arguments(batch_id)
        end
      end

      def select_batches(&block)
        list_batches.select do |batch_id|
          yield fetch_batch_arguments(batch_id)
        end
      end

      def poll
        while true
          sleep 2
          EasyML::BatchJob.list_batches.map do |batch|
            puts "Batch #{batch} | Remaining : #{EasyML::BatchJob.batches_remaining(batch)}"
          end
        end
      end

      def get_parent_batch_id(args_list)
        args_list.dup.flatten.detect { |arg| arg.dig(:parent_batch_id) }.dig(:parent_batch_id)
      end

      private

      def get_args_list(batch_id)
        redis_key = "#{batch(batch_id)}:original_args"
        redis.get(redis_key)
      end

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
