class CreateCrafts < ActiveRecord::Migration
  def change
    create_table :crafts do |t|
      t.string :name
      t.string :craft_type
      t.boolean :deleted, :default => false
      t.integer :campaign_id

      t.timestamps
    end
  end
end
