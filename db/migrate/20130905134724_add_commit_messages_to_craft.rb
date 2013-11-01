class AddCommitMessagesToCraft < ActiveRecord::Migration
  def change
    add_column :crafts, :commit_messages, :text, :limit => nil 
  end
end
