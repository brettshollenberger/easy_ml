module FileSpecHelper
  def file_spec
    path = SPEC_ROOT.join("lib/easy_ml/data/dataset/data/files/raw")
    csv_path = path.join("file.csv")
    parquet_path = path.join("parquet/file.parquet")
    restore_path = SPEC_ROOT.join("file.csv")

    FileUtils.cp(csv_path, restore_path)

    yield path, restore_path, parquet_path
  ensure
    FileUtils.rm(parquet_path) if File.exist?(parquet_path)
    FileUtils.mv(restore_path, csv_path)
  end
end
