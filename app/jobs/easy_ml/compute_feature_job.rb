module EasyML
  class ComputeFeatureJob < BatchJob
    extend EasyML::DataframeSerialization

    @queue = :easy_ml

    def self.perform(batch_id, options = {})
      options.symbolize_keys!
      feature_id = options.dig(:feature_id)
      feature = EasyML::Feature.find(feature_id)
      dataset = feature.dataset

      # Check if any feature has failed before proceeding
      if dataset.features.any? { |f| f.workflow_status == "failed" }
        puts "Aborting feature computation due to previous feature failure"
        return
      end

      begin
        feature.update(workflow_status: :analyzing) if feature.workflow_status == :ready
        feature.fit_batch(options.merge!(batch_id: batch_id))
      rescue => e
        EasyML::Feature.transaction do
          return if dataset.reload.workflow_status == :failed

          feature.update(workflow_status: :failed)
          dataset.update(workflow_status: :failed)
          build_error_with_context(dataset, e, batch_id, feature)
        end
      end
    end

    def self.build_error_with_context(dataset, error, batch_id, feature)
      error = EasyML::Event.handle_error(dataset, error)
      batch = feature.build_batch(batch_id: batch_id)

      # Convert any dataframes in the context to serialized form
      error.create_context(context: batch)
    end

    def self.after_batch_hook(batch_id, *args)
      puts "After batch!"
      batch_args = fetch_batch_arguments(batch_id).flatten.map(&:symbolize_keys)
      feature_ids = batch_args.pluck(:feature_id).uniq
      parent_id = batch_args.pluck(:parent_batch_id).first

      feature = EasyML::Feature.find_by(id: feature_ids.first)

      if feature.failed?
        dataset.features.where(workflow_status: :analyzing).update_all(workflow_status: :ready)
        return BatchJob.cleanup_batch(parent_id)
      end

      feature.update(workflow_status: :ready, fit_at: Time.current)

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
