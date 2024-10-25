# == Schema Information
#
# Table name: easy_ml_model_files
#
#  id            :bigint           not null, primary key
#  filename      :string           not null
#  path          :string           not null
#  configuration :json
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
require_relative "concerns/statuses"

module EasyML
  class ModelFile < ActiveRecord::Base
    self.filter_attributes += [:configuration]

    include GlueGun::Model
    service :synced_file, EasyML::Support::SyncedFile

    validates :filename, presence: true
    belongs_to :model, class_name: "EasyML::Model"

    def upload(path)
      model_file_service.upload(path)

      self.filename = Pathname.new(path).basename.to_s
      path = path.split(Rails.root.to_s).last
      path = path.split("/")[0..-2].reject(&:empty?).join("/")
      self.path = path
    end

    def download
      model_file_service.download(full_path) unless File.exist?(full_path)
    end

    def full_path(filename = nil)
      filename = self.filename if filename.nil?
      Rails.root.join(relative_dir, filename).to_s
    end

    def relative_dir
      base_path = root_dir.split(Regexp.new(Rails.root.to_s)).last.split("/").reject(&:empty?).join("/")
      File.join(base_path, store_dir)
    end

    def full_dir
      Rails.root.join(relative_dir)
    end

    def cleanup!
      [full_dir].each do |dir|
        EasyML::FileRotate.new(dir, []).cleanup(extension_allowlist)
      end
    end

    def cleanup(files_to_keep)
      [full_dir].each do |dir|
        EasyML::FileRotate.new(dir, files_to_keep).cleanup(extension_allowlist)
      end
    end

    def extension_allowlist
      %w[bin model json]
    end

    def store_dir
      base = ENV["EASY_ML_MODEL_DIRECTORY"] || "easy_ml_models"
      return base unless model.present?

      File.join(base, model.name)
    end
  end
end
