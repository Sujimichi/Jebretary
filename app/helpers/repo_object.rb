module RepoObject

  #return true if the craft is not yet in the repo
  def is_new?
    return false if deleted?
    repo.untracked.include?(local_path)
  end

  #return true if the craft is in the repo and has changes.  If not in repo it returns nil.
  def is_changed? 
    return nil if is_new? 
    return false if deleted?
    repo.changed.include?(local_path)
  end

  #return the commits for the craft (most recent first)
  def history args = {:limit => false}
    return [] if is_new? || deleted?
    begin
      logs = repo.log(local_path, :limit => args[:limit])
    rescue
      []
    end
  end
end
