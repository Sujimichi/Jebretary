class CreateTasks < ActiveRecord::Migration
  def change
    create_table :tasks do |t|
      t.string :action
      t.boolean :failed, :default => false

      t.timestamps
    end
  end
end
