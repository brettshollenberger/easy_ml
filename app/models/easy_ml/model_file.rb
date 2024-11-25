# == Schema Information
#
# Table name: easy_ml_model_files
#
#  id            :bigint           not null, primary key
#  filename      :string           not null
#  path          :string           not null
#  configuration :json
#  model_id      :bigint
#  model_type    :string
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
module EasyML
  class ModelFile < ActiveRecord::Base
    self.table_name = "easy_ml_model_files"
    include Historiographer::Silent
    historiographer_mode :snapshot_only

    self.filter_attributes += [:configuration]

    validates :filename, presence: true
    belongs_to :model, polymorphic: true

    include EasyML::Concerns::Configurable
    add_configuration_attributes :s3_bucket, :s3_prefix, :s3_region, :s3_access_key_id, :s3_secret_access_key, :root_dir
    attr_accessor :s3_bucket, :s3_prefix, :s3_region, :s3_access_key_id, :s3_secret_access_key, :root_dir

    def synced_file
      EasyML::Support::SyncedFile.new(
        filename: filename,
        s3_bucket: s3_bucket,
        s3_prefix: s3_prefix,
        s3_region: s3_region,
        s3_access_key_id: s3_access_key_id,
        s3_secret_access_key: s3_secret_access_key,
        root_dir: root_dir,
      )
    end

    def exist?
      fit?
    end

    def fit?
      return false if full_path.nil?

      File.exist?(full_path)
    end

    def read
      File.read(full_path)
    end

    def upload(path)
      synced_file.upload(path)

      self.filename = Pathname.new(path).basename.to_s
      path = path.split(Rails.root.to_s).last
      path = path.split("/")[0..-2].reject(&:empty?).join("/")
      self.path = path
    end

    def download
      synced_file.download(full_path) unless File.exist?(full_path)
      full_path
    end

    def full_path(filename = nil)
      filename = self.filename if filename.nil?
      return nil if filename.nil?

      Rails.root.join(relative_dir, filename).to_s
    end

    def relative_dir
      base_path = root_dir.to_s.gsub(Regexp.new(Rails.root.to_s), "")
      path = File.join(base_path, store_dir)
      path.gsub!(%r{^/}, "")
      path
    end

    def full_dir
      Rails.root.join(relative_dir)
    end

    def cleanup!
      [full_dir].each do |dir|
        EasyML::Support::FileRotate.new(dir, []).cleanup(extension_allowlist)
      end
    end

    def cleanup(files_to_keep)
      [full_dir].each do |dir|
        EasyML::Support::FileRotate.new(dir, files_to_keep).cleanup(extension_allowlist)
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
