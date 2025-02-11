# == Schema Information
#
# Table name: easy_ml_lineages
#
#  id          :bigint           not null, primary key
#  column_id   :bigint           not null
#  key         :string           not null
#  description :string
#  occurred_at :datetime
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
module EasyML
  class Lineage < ActiveRecord::Base
    belongs_to :column

    class << self
      def learn(column)
        @lineage = EasyML::Column::Lineage.new(column).lineage

        existing_lineage = where(column_id: column.id)
        missing_lineage = @lineage.select { |l| !existing_lineage.exists?(key: l[:key]) }

        missing_lineage = missing_lineage.map { |l|
          EasyML::Lineage.new(
            column_id: column.id,
            key: l[:key],
            occurred_at: l[:occurred_at],
            description: l[:description],
          )
        }
        existing_lineage = existing_lineage.map do |lineage|
          matching_lineage = @lineage.detect { |ll| ll[:key].to_sym == lineage.key.to_sym }

          binding.pry unless matching_lineage
          lineage&.assign_attributes(
            occurred_at: matching_lineage[:occurred_at],
            description: matching_lineage[:description],
          )
        end
        missing_lineage.concat(existing_lineage)
      end
    end
  end
end
