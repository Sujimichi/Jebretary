class AddCommitMessageToCraft < ActiveRecord::Migration
  def change
    add_column :crafts, :commit_message, :text
  end
end
