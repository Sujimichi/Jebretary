class CreateCampaigns < ActiveRecord::Migration
  def change
    create_table :campaigns do |t|
      t.integer :instance_id
      t.string :name

      t.string :persistence_checksum

      t.timestamps
    end
  end
end
