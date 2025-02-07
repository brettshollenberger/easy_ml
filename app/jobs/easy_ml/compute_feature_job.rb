module EasyML
  class ComputeFeatureJob < BatchJob
    extend EasyML::DataframeSerialization

    @queue = :easy_ml

    def self.perform(batch_id, batch_args = {})
      begin
        puts "ComputeFeatureJob.perform(#{batch_id}, #{batch_args})"
        run_one_batch(batch_id, batch_args)
      rescue => e
        EasyML::Feature.transaction do
          return if dataset.reload.workflow_status == :failed

          feature.update(workflow_status: :failed)
          dataset.update(workflow_status: :failed)
          build_error_with_context(dataset, e, batch_id, feature)
        end
      end
    end

    def self.run_one_batch(batch_id, batch_args)
      EasyML::Feature.fit_one_batch(batch_id, batch_args)
    end

    def self.build_error_with_context(dataset, error, batch_id, feature)
      error = EasyML::Event.handle_error(dataset, error)
      batch = feature.build_batch(batch_id: batch_id)

      # Convert any dataframes in the context to serialized form
      error.create_context(context: batch)
    end

    def self.after_batch_hook(batch_id, *args)
      puts "Received after_batch_hook(#{batch_id}, #{args})"
      batch_args = fetch_batch_arguments(batch_id).flatten.map(&:symbolize_keys)
      feature_ids = batch_args.pluck(:feature_id).uniq
      parent_id = batch_args.pluck(:parent_batch_id).first

      feature = EasyML::Feature.find_by(id: feature_ids.first)

      if feature.failed?
        dataset.features.where(workflow_status: :analyzing).update_all(workflow_status: :ready)
        return BatchJob.cleanup_batch(parent_id)
      end

      feature.after_fit

      puts "Analyzing next feature..."
      if BatchJob.next_batch?(parent_id)
        BatchJob.enqueue_next_batch(self, parent_id)
      else
        dataset = EasyML::Feature.find_by(id: feature_ids.first).dataset
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
