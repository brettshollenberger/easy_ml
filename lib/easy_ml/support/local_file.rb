module EasyML
  module Support
    class LocalFile
      attr_accessor :root_dir, :filename

      def initialize(options = {})
        @root_dir = options[:root_dir]
        @filename = options[:filename]
      end

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
