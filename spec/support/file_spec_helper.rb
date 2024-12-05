require "thread"
module FileSpecHelper
  MUTEX = Mutex.new

  def file_spec
    MUTEX.synchronize do
      path = SPEC_ROOT.join("internal/easy_ml/datasources/single_file")
      csv_path = path.join("file.csv")
      parquet_path = path.join("file.parquet")
      restore_path = SPEC_ROOT.join("internal/file.csv")

      FileUtils.cp(csv_path, restore_path)

      yield path, restore_path, parquet_path
    ensure
      FileUtils.rm(parquet_path) if File.exist?(parquet_path)
      FileUtils.mv(restore_path, csv_path)
    end
  end
end
