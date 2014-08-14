class RemoveX64AvailableFromInstances < ActiveRecord::Migration
  def change
    remove_column :instances, :x64_available
  end
end
