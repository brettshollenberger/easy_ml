module EasyML
  class ComputeFeatureJob < BatchJob
    extend EasyML::DataframeSerialization

    @queue = :easy_ml

    def self.perform(batch_id, batch_args = {})
      # This is very, very, very, very, very important
      # if you don't dup the batch_args, resque-batched-job will
      # fail in some non-obvious ways, because it will try to
      # decode to match the original batch args EXACTLY.
      #
      # This will waste your time so please just don't remove this .dup!!!
      #
      # https://github.com/drfeelngood/resque-batched-job/blob/master/lib/resque/plugins/batched_job.rb#L86
      batch_args = batch_args.dup
      EasyML::ComputeFeatureJob.new.perform(batch_id, batch_args)
    end

    def perform(batch_id, batch_args = {})
      EasyML::Feature.fit_one_batch(batch_id, batch_args)
    end

    def self.after_batch_hook(batch_id, *args)
      args = args.flatten.first.with_indifferent_access
      feature_id = args.dig(:feature_id)

      feature = EasyML::Feature.find_by(id: feature_id)

      if feature.failed?
        dataset.features.where(workflow_status: :analyzing).update_all(workflow_status: :ready)
        return BatchJob.cleanup_batch(batch_id)
      end

      feature.after_fit

      if BatchJob.next_batch?(batch_id)
        BatchJob.enqueue_next_batch(self, batch_id)
      else
        cleanup_batch(batch_id)
        dataset = feature.dataset
        dataset.after_fit_features
      end
    end

    private

    def self.remove_remaining_batch_jobs(batch_id)
      # Remove all remaining jobs in the batch
      while (jobs = Resque.peek(:easy_ml, 0, 1000)).any?
        jobs.each do |job|
          if job["args"][0] == batch_id
            Resque.dequeue(self, *job["args"])
          end
        end

        # Break if we've processed all jobs (no more jobs match our batch_id)
        break unless jobs.any? { |job| job["args"][0] == batch_id }
      end
    end
  end
end

# If any feature fails, the entire batch fails
# If any feature fails, the RELATED batches should fail
