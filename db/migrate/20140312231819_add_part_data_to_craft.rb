class AddPartDataToCraft < ActiveRecord::Migration
  def self.up
    add_column :crafts, :part_data, :text, :limit => nil
  end

  def self.down
    remove_column :crafts, :part_data
  end
end
