module EasyML
  class Cleaner
    attr_accessor :files_to_keep, :dirs_to_clean

    def initialize(force: false, verbose: false)
      @verbose = verbose
      @files_to_keep = if force
                         []
                       else
                         model_files_to_keep +
                           dataset_files_to_keep +
                           datasource_files_to_keep
                       end
    end

    def self.clean(verbose: false)
      new(verbose: verbose).clean
    end

    # Clean everything, including active models
    def self.clean!(verbose: false)
      new(force: true, verbose: verbose).clean
    end

    def clean
      dirs_to_clean.each do |dir|
        files_to_keep = files_to_keep_for_dir(dir)
        EasyML::Support::FileRotate.new(dir, files_to_keep, verbose: @verbose).cleanup(%w[json parquet csv])
      end
    end

    private

    def files_to_keep_for_dir(dir)
      files_to_keep.map(&:to_s).select { |f| f.start_with?(dir) }
    end

    def dirs_to_clean
      %w[models datasets datasources].map do |dir|
        EasyML::Engine.root_dir.join(dir)
      end
    end

    def model_dirs
      EasyML::Model.all.includes(dataset: :datasource).map do |model|
        File.expand_path("..", model.root_dir)
      end
    end

    def active_models
      @active_models ||= begin
        inference_models = EasyML::ModelHistory.latest_snapshots
        training_models = EasyML::Model.all
        (training_models + inference_models).compact
      end
    end

    def model_files_to_keep
      active_models.map(&:model_file).compact.map(&:full_path).uniq
    end

    def dataset_files_to_keep
      EasyML::Dataset.all.flat_map(&:files).uniq
    end

    def datasource_files_to_keep
      if Rails.env.test?
        Dir.glob(EasyML::Engine.root_dir.glob("datasources/**/*.{csv}")).uniq
      else
        EasyML::Datasource.all.flat_map(&:files).uniq
      end
    end
  end
end
