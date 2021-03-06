class CreateCrafts < ActiveRecord::Migration
  def change
    create_table :crafts do |t|
      t.string :name
      t.string :craft_type
      t.integer :part_count
      t.boolean :deleted, :default => false
      t.integer :campaign_id
      t.integer :history_count
      t.string  :last_commit

      t.timestamps
    end
  end
end
