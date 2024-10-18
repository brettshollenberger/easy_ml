module EasyML
  class FileRotate
    def initialize(directory, files_to_keep)
      @directory = directory
      @files_to_keep = files_to_keep
    end

    def cleanup(allowed_endings = %w[json])
      return unless @directory.present?

      allowed_patterns = allowed_endings.map { |ending| File.join(@directory, "**", "*#{ending}") }
      files_to_check = allowed_patterns.empty? ? Dir.glob(File.join(@directory, "**/*")) : Dir.glob(allowed_patterns)
      # Filter out directories
      files_to_check = files_to_check.select { |file| File.file?(file) }

      files_to_check.each do |file|
        FileUtils.chown_R(`whoami`.chomp, "staff", file)
        FileUtils.chmod_R(0o777, file)
        File.delete(file) if @files_to_keep.exclude?(file) && File.exist?(file)
      end
    end
  end
end
