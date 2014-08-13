class AddStartupExeOptionsToInstances < ActiveRecord::Migration
  def change
    add_column :instances, :x64_available, :boolean, :default => false
    add_column :instances, :use_x64_exe, :boolean, :default => false
  end
end
