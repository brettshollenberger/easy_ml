module EasyML
  module Splitters
    class PredefinedSplitter < BaseSplitter
      validates :train_files, :test_files, :valid_files, presence: true
      validate :files_must_be_unique
      validate :at_least_one_file_specified

      add_configuration_attributes :train_files, :test_files, :valid_files

      def self.default_config
        {
          train_files: ["train.csv"],
          test_files: ["test.csv"],
          valid_files: ["valid.csv"],
        }
      end

      def split(dataset, &block)
        validate!

        files = dataset.datasource.all_files
        train, valid, test = match_files(files)

        values = [reader.query(train), reader.query(valid), reader.query(test)]
        if block_given?
          yield values
        else
          values
        end
      end

      def match_files(files)
        train = select_preferred_files(files.select { |file| match_file(file, train_files) })
        test = select_preferred_files(files.select { |file| match_file(file, test_files) })
        valid = select_preferred_files(files.select { |file| match_file(file, valid_files) })

        [train, valid, test]
      end

      def select_preferred_files(files)
        # Group files by their base name (without extensions)
        grouped = files.group_by { |f| Pathname.new(f).basename.to_s.gsub(/\.parquet$/, "").gsub(/\.[^.]+$/, "") }

        # For each group, prefer parquet if it exists, otherwise use csv
        grouped.map do |_, group_files|
          parquet_file = group_files.find { |f| f.end_with?(".parquet") }
          parquet_file || group_files.first
        end
      end

      def match_file(file, type)
        base_name = Pathname.new(file).basename.to_s
        # Strip both .parquet and original extension
        filename = base_name.gsub(/\.parquet$/, "").gsub(/\.[^.]+$/, "")

        type.map { |f| f.gsub(/\.[^.]+$/, "") }.include?(filename)
      end

      private

      def reader
        @reader ||= EasyML::Data::PolarsReader.new
      end

      def files_must_be_unique
        all_files = train_files + test_files + valid_files
        if all_files.uniq.length != all_files.length
          errors.add(:base, "Files must be unique across splits")
        end
      end

      def at_least_one_file_specified
        if train_files.empty? && test_files.empty? && valid_files.empty?
          errors.add(:base, "At least one file must be specified")
        end
      end
    end
  end
end
