class Subassembly < ActiveRecord::Base
  include RepoObject

  attr_accessible :campaign_id, :history_count, :name, :deleted
  belongs_to :campaign


  def path campaign_path = nil
    campaign_path ||= self.campaign.path
    File.join([campaign_path,"Subassemblies", "#{self.name}.craft"])
  end

  def local_path
    File.join(["Subassemblies", "#{self.name}.craft"])
  end

  def repo
    return @repo if defined?(@repo) && !@repo.nil?
    @repo = self.campaign.repo
  end
  
  def commit repo = self.campaign.repo
    action = :deleted if self.deleted?
    action ||= self.is_new? ? :added : (self.is_changed? ? :updated : :nothing_to_commit)     

    unless action.eql?(:nothing_to_commit)
      message = "#{action} subassembly: #{name}"
      if action.eql?(:deleted)
        repo.remove(self.local_path)
        self.history_count ||= 0
        self.history_count += 1
      else
        repo.add(self.local_path)
      end

      repo.commit message
      self.last_commit = history(:limit => 1).first.to_s
    end

    unless action.eql?(:deleted)
      self.history_count = self.history.count
      self.history_count = 1 if self.history_count.eql?(0)
    end
    
    self.save if self.changed?
  end


end
