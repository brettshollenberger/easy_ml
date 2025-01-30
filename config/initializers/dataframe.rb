class Polars::DataFrame
  def to_hash
    if columns.count == 2
      to_a.map(&:values).to_h
    else
      self
    end
  end
end
