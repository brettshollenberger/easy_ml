module EasyML
  class Dataset
    class RefreshReasons < EasyML::Reasons
      add_reason "Not split", -> { not_split? }
      add_reason "Refreshed at is nil", -> { refreshed_at.nil? }
      add_reason "Columns need refresh", -> { columns_need_refresh? }
      add_reason "Features need fit", -> { features_need_fit? }
      add_reason "Datasource needs refresh", -> { datasource_needs_refresh? }
      add_reason "Refreshed was datasource", -> { datasource_was_refreshed? }
    end
  end
end
