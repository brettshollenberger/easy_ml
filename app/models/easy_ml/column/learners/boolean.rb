module EasyML
  class Column
    module Learners
      class Boolean < Categorical
        def sort_by(value)
          value == true ? 1 : 0
        end
      end
    end
  end
end
