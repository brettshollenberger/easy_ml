module EasyML
  module Data
    module Utils
      def append_to_csv(df, path)
        return if df.empty?

        path = Pathname.new(path) if path.is_a?(String)
        FileUtils.mkdir_p(path.dirname)
        FileUtils.touch(path)

        # Check if the file is empty (i.e., if this is the first write)
        file_empty = File.zero?(path)

        # Write the DataFrame to a temporary file
        temp_file = "#{path}.tmp"
        df.write_csv(temp_file)

        # Append the content to the main file, skipping the header if not the first write
        File.open(path, "a") do |f|
          File.foreach(temp_file).with_index do |line, index|
            # Skip the header line if the file is not empty
            f.write(line) unless index == 0 && !file_empty
          end
        end

        # Delete the temporary file
        File.delete(temp_file)
      end

      def expand_dir(dir)
        return dir if dir.to_s[0] == "/"

        Rails.root.join(dir)
      end

      def null_check(df)
        result = {}
        null_counts = df.null_count
        total_count = df.height
        df.columns.each do |column|
          null_count = null_counts[column][0]
          next if null_count == 0

          result[column] = { null_count: null_count, total_count: total_count }
        end
        result.empty? ? nil : result
      end
    end
  end
end
