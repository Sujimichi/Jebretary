module RepoObject

  #return true if the craft/subassembly is not yet in the repo
  def is_new?
    return false if deleted?
    repo.untracked.include?(local_path)
  end

  #return true if the craft/subassembly is in the repo and has changes.  If not in repo it returns nil.
  def is_changed? 
    return nil if is_new? 
    return false if deleted?
    repo.changed.include?(local_path)
  end

  #return the commits for the craft/subassembly (most recent first)
  def history args = {:limit => false}
    return [] if is_new? || deleted?
    begin
      logs = repo.log(local_path, :limit => args[:limit])
    rescue
      []
    end
  end

  #update the attribute which tracks the count of commits for this craft/subassembly
  def update_history_count
    self.update_attributes(:history_count => self.history.size)   
  end

  #revert the craft/subassembly to a previous commit
  def revert_to commit, options = {:commit => true}
    camp = self.campaign
    camp.dont_process_while do 
      repo = camp.repo
      index = history.reverse.map{|c| c.to_s}.index(commit.to_s) + 1
      repo.checkout_file(commit, local_path)
      message = "reverted #{name} to V#{index}"
      if options[:commit]
        begin          
          repo.commit(message)
        rescue
        end
        update_history_count
      else
        cms = self.commit_messages
        cms["most_recent"] = message
        self.commit_messages = cms       
      end
      self.save
    end
  end


end


