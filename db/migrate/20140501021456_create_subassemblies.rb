class CreateSubassemblies < ActiveRecord::Migration
  def change
    create_table :subassemblies do |t|
      t.string :name
      t.integer :campaign_id
      t.integer :history_count
      t.boolean :deleted, :default => false
      t.string  :last_commit
      t.timestamps
    end
  end
end
