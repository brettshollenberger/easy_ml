module EasyML
  class FileDownloadWorker
    include Sidekiq::Worker

    sidekiq_options queue: :easy_ml, retry: 3

    def perform(datasource_id, file_info)
      datasource = EasyML::Datasource.find(datasource_id)
      file = JSON.parse(file_info).symbolize_keys
      datasource.download_file(OpenStruct.new(file))
    rescue StandardError => e
      Rails.logger.error("Failed to download file #{file[:key]}: #{e.message}")
      raise e
    end
  end
end
