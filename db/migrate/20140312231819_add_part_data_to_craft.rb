class AddPartDataToCraft < ActiveRecord::Migration
  def self.up
    add_column :craft, :part_data, :string
  end

  def self.down
    remove_column :craft, :part_data
  end
end
