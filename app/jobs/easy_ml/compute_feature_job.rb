module EasyML
  class ComputeFeatureJob < BatchJob
    @queue = :easy_ml

    def self.perform(batch_id, options = {})
      puts "processing batch_id #{batch_id}"
      options.symbolize_keys!
      feature_id = options.dig(:feature_id)
      feature = EasyML::Feature.find(feature_id)
      dataset = feature.dataset

      # Check if any feature has failed before proceeding
      if dataset.features.any? { |f| f.workflow_status == "error" }
        puts "Aborting feature computation due to previous feature failure"
        return
      end

      begin
        feature.fit_batch(options.merge!(batch_id: batch_id))
      rescue StandardError => e
        puts "Error computing feature: #{e.message}"
        feature.update(workflow_status: :error)
        dataset.update(workflow_status: :error)
        handle_error(dataset, e)
        raise e if Rails.env.test?
      end
    end

    def self.handle_error(dataset, error)
      EasyML::EventContext.create!(
        dataset: dataset,
        event_type: "error",
        message: error.message,
        backtrace: error.backtrace,
        workflow_status: "error",
      )
    end

    def self.after_batch_hook(batch_id, *args)
      puts "After batch!"
      feature_ids = fetch_batch_arguments(batch_id).flatten.map(&:symbolize_keys).pluck(:feature_id).uniq
      dataset = EasyML::Feature.find_by(id: feature_ids.first).dataset
      dataset.after_fit_features
    end

    def self.feature_fully_processed?(feature)
    end
  end
end

# If any feature fails, the entire batch fails
# If any feature fails, the RELATED batches should fail
