# == Schema Information
#
# Table name: easy_ml_model_files
#
#  id            :bigint           not null, primary key
#  filename      :string           not null
#  configuration :json
#  model_type    :string
#  model_id      :bigint
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
    belongs_to :model, class_name: "EasyML::Model"

    include EasyML::Concerns::Configurable
    add_configuration_attributes :s3_bucket, :s3_prefix, :s3_region, :s3_access_key_id, :s3_secret_access_key

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

    def s3_prefix
      EasyML::Configuration.model_s3_path(model.name)
    end

    def root_dir
      Pathname.new(model.root_dir)
    end

    def model_root
      File.expand_path("..", root_dir.to_s)
    end

    def full_path(filename = nil)
      filename = self.filename if filename.nil?
      return nil if filename.nil?

      root_dir.join(filename).to_s
    end

    def exist?
      fit?
    end

    def fit?
      return false if root_dir.nil?
      return false if full_path.nil?

      File.exist?(full_path)
    end

    def read
      File.read(full_path)
    end

    def upload(path)
      synced_file.upload(path)
      update(filename: Pathname.new(path).basename.to_s)
    end

    def download
      return unless full_path.present?

      synced_file.download(full_path) unless File.exist?(full_path)
      full_path
    end

    def sha
      Digest::SHA256.file(full_path).hexdigest
    end

    def cleanup!
      [model_root].each do |dir|
        EasyML::Support::FileRotate.new(dir, []).cleanup(extension_allowlist)
      end
    end

    def cleanup(files_to_keep)
      [model_root].each do |dir|
        EasyML::Support::FileRotate.new(dir, files_to_keep).cleanup(extension_allowlist)
      end
    end

    def extension_allowlist
      %w[bin model json]
    end

    def write(content)
      FileUtils.mkdir_p(File.dirname(full_path))
      File.write(full_path, content)
      upload(full_path)
    end
  end
end
