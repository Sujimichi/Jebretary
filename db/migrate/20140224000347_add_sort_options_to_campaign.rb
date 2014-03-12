class AddSortOptionsToCampaign < ActiveRecord::Migration
  def self.up
    add_column :campaigns, :sort_options, :string
  end

  def self.down
    remove_column :campaigns, :sort_options
  end
end
