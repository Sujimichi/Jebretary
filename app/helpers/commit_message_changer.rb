module CommitMessageChanger
  #git branch temp refb
  #git filter-branch -f --msg-filter "sed 's/test/testy/'" refa..temp
  #git rebase temp
  #git branch --delete temp
  def change_commit_message commit, new_message
    return nil unless commit
    if self.is_a?(Campaign)
      campaign = self 
    elsif self.is_a?(Craft)
      campaign = self.campaign
    end
    rebase_ok = false
    repo = campaign.repo
    temp_branch_name = "message_rewrite"

    if campaign.nothing_to_commit? #message cannot be changed if there are untracked changes in the repo     
      #create a new branch with it's head as the commit I want to change (refb)
      repo.checkout "#{commit.sha_id} -b #{temp_branch_name}"

      #and switch back to master
      repo.checkout("master")

      #This part uses system commands to interact with the git repo as 
      #I couldn't find a way using the git-gem to do filter-branch actions
      #used filter-branch with -msg-filter to replace text on all commits from the targets parent to the branch's head (which is just the desired commit)       
      repo.filter_branch "-f --msg-filter \"sed 's/#{commit.message}/#{new_message}/'\" #{commit.parent}..#{temp_branch_name}"

      #perform rebase only if there have not been any changes since the process started.
      if repo.changed.empty?
        #rebase the temp branch back into master
        begin
          repo.rebase "#{temp_branch_name}"
          rebase_ok = true
        rescue
          rebase_ok = false
        end
      end

      #clean up - delete the temp branch
      repo.branch "#{temp_branch_name} -D"

      if rebase_ok      
        return true
      else        
        puts "WARNING: rebase failed, aborting" unless Rails.env.eql?("test")
        repo.rebase "--abort"
        return false
      end
    else
      repo.rebase "--abort"
      return false
    end
  end
end
