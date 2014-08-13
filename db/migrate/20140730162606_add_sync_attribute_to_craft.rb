class AddSyncAttributeToCraft < ActiveRecord::Migration
  def change
    add_column :crafts, :sync, :string
  end
end
