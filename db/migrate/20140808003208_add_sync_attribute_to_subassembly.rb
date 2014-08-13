class AddSyncAttributeToSubassembly < ActiveRecord::Migration
  def change
    add_column :subassemblies, :sync, :string
  end
end
