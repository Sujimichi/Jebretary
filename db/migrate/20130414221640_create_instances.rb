class CreateInstances < ActiveRecord::Migration
  def change
    create_table :instances do |t|
      t.string :full_path

      t.timestamps
    end
  end
end
