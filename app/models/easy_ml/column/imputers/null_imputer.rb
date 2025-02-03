module EasyML
  class Column
    class Imputers
      class NullImputer
        def anything?
          false
        end

        def method_missing(_name, df)
          df
        end
      end
    end
  end
end
