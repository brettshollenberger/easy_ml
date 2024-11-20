module EasyML
  module Support
    module FileSupport
      def ensure_directory_exists(dir)
        FileUtils.mkdir_p(dir) unless File.directory?(dir)
      end
    end
  end
end
