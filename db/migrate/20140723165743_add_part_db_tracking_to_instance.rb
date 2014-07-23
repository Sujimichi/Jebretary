class AddPartDbTrackingToInstance < ActiveRecord::Migration
  def self.up
    add_column :instances, :part_db_checksum, :string
    add_column :instances, :part_update_required, :boolean, :default => false
  end

  def self.down
    remove_column :instances, :part_db_checksum
    remove_column :instances, :part_update_required
  end
end
