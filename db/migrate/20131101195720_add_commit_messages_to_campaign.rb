class AddCommitMessagesToCampaign < ActiveRecord::Migration
  def change
    add_column :campaigns, :commit_messages, :text, :limit => nil
  end
end
