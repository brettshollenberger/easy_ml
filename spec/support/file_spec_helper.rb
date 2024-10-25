module FileSpecHelper
  def file_spec
    path = SPEC_ROOT.join("lib/easy_ml/data/dataset/data/files/raw")
    csv_file = path.join("file.csv")
    parquet_file = path.join("file.parquet")

    FileUtils.cp(csv_file, SPEC_ROOT.join("file.csv")) # This gets wiped by PolarsReader

    yield csv_file, parquet_file
  ensure
    FileUtils.rm(path.join("file.parquet")) if File.exist?(path.join("file.parquet"))
    FileUtils.mv(SPEC_ROOT.join("file.csv"), csv_file)
  end
end
