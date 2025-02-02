module Enumerable
  def count_by(&block)
    self.group_by(&block).inject({}) do |h, (k, v)|
      h.tap do
        h[k] = v.count
      end
    end
  end

  def key_by(&block)
    self.group_by(&block).inject({}) do |h, (k, v)|
      h.tap do
        h[k] = v.first
      end
    end
  end
end
