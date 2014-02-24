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

    if campaign.nothing_to_commit? #message cannot be changed if there are untracked changes in the repo
      #dont_process_campaign_while do 

      rebase_ok = false
      repo = campaign.repo
      temp_branch_name = "temp_message_change_branch"

      #create a new branch with it's head as the commit I want to change (refb)
      repo.checkout(commit)
      repo.branch(temp_branch_name).checkout
      #and switch back to master
      repo.checkout("master")

      #This part uses system commands to interact with the git repo as 
      #I couldn't find a way using the git-gem to do filter-branch actions
      repo.with_working(campaign.path) do
        #used filter-branch with -msg-filter to replace text on all commits from the targets parent to the branch's head (which is just the desired commit)
        `git filter-branch -f --msg-filter \"sed 's/#{commit.message}/#{new_message}/'\" #{commit.parent}..#{temp_branch_name}`
        #refs/heads/temp_message_change_branch' was rewritten

        #perform rebase only if there have not been any changes since the process started.
        if repo.status.changed.empty?
          #rebase the temp branch back into master
          begin
            `git rebase #{temp_branch_name}`
            rebase_ok = true
          rescue
            rebase_ok = false
          end
        end
      end

      #clean up - delete the temp branch
      repo.branch(temp_branch_name).delete

      if rebase_ok
        puts "WARNING: rebase failed, aborting"
        return true
      else            
        `git rebase --abort`
        return false
      end
    else
      `git rebase --abort`
      return false
    end
  end


end
