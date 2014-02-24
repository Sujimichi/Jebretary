class AddSortOptionsToCampaign < ActiveRecord::Migration
  def self.up
    add_column :campaigns, :sort_options, :string
  end

  def self.down
    _column :campaigns, :sort_options
  end
end
