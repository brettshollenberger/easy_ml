require "glue_gun"

module EasyML
  module Support
    class LocalFile
      include GlueGun::DSL

      attribute :root_dir, :string
      attribute :filename, :string

      def upload(file_path)
        file_path
      end

      def download(full_path)
        full_path
      end

      def synced?
        true
      end
    end
  end
end
