module EasyML
  class Dataset
    class RefreshReasons < EasyML::Reasons
      add_reason "Not split", -> { splits.empty? }
      add_reason "Refreshed at is nil", -> { refreshed_at.nil? }
      add_reason "Columns need refresh", -> { columns.any?(&:needs_refresh?) }
      add_reason "Features need fit", -> { features.any?(&:needs_fit?) }
      add_reason "Datasource needs refresh", -> { datasource&.needs_refresh? }
      add_reason "Refreshed datasource", -> { datasource&.refreshed? }
      add_reason "Datasource was refreshed", -> { last_datasource_sha != datasource&.sha }
    end
  end
end
