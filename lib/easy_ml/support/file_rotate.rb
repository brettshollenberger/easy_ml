module EasyML
  module Support
    class FileRotate
      def initialize(directory, files_to_keep, verbose: false)
        @directory = directory
        @files_to_keep = files_to_keep
        @stats = { checked: 0, kept: 0, deleted: 0 }
        @verbose = verbose
      end

      def cleanup(allowed_endings = [])
        return unless @directory.present?

        log "\nStarting file rotation in: #{@directory}"
        log "Files to keep: #{@files_to_keep.count}"

        process_directory(@directory, allowed_endings)
        cleanup_empty_directories(@directory)

        log "\nFile rotation complete:"
        log "Files checked: #{@stats[:checked]}"
        log "Files kept: #{@stats[:kept]}"
        log "Files deleted: #{@stats[:deleted]}"
      end

      private

      def process_directory(dir, allowed_endings)
        return unless Dir.exist?(dir)

        log "\nProcessing directory: #{dir}"

        if @files_to_keep.include?(dir)
          log "  Keeping entire directory: #{dir}"
          @stats[:kept] += 1
          return
        end

        allowed_patterns = allowed_endings.map { |ending| File.join(dir, "*#{ending}") }
        files_to_check = allowed_patterns.empty? ? Dir.glob(File.join(dir, "*")) : Dir.glob(allowed_patterns)

        files_to_check.each do |file|
          next unless File.file?(file)

          @stats[:checked] += 1

          FileUtils.chown_R(`whoami`.chomp, "staff", file)
          FileUtils.chmod_R(0o777, file)

          if @files_to_keep.exclude?(file) && File.exist?(file)
            log "  Deleting: #{file}"
            File.delete(file)
            @stats[:deleted] += 1
          else
            log "  Keeping: #{file}"
            @stats[:kept] += 1
          end
        end

        Dir.each_child(dir) do |child|
          full_path = File.join(dir, child)
          process_directory(full_path, allowed_endings) if File.directory?(full_path)
        end
      end

      def cleanup_empty_directories(dir)
        return unless Dir.exist?(dir)

        Dir.each_child(dir) do |child|
          full_path = File.join(dir, child)
          cleanup_empty_directories(full_path) if File.directory?(full_path)
        end

        if Dir.empty?(dir) && dir != @directory
          log "Removing empty directory: #{dir}"
          Dir.rmdir(dir)
        end
      rescue Errno::ENOTEMPTY, Errno::EACCES
        # Directory not empty or permission denied - skip it
      end

      def log(message)
        puts message if @verbose
      end
    end
  end
end
