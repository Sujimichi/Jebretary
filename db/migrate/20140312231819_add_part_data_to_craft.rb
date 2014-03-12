class AddPartDataToCraft < ActiveRecord::Migration
  def self.up
    add_column :crafts, :part_data, :string
  end

  def self.down
    remove_column :crafts, :part_data
  end
end
