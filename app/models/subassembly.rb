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

  def commit repo = self.campaign.repo
    if repo.untracked.include? ("Subassemblies/#{self.name}.craft")
      message = "added subassembly: #{name}"
    else
      message = "updated subassembly: #{name}"
    end
    repo.add self.path
    repo.commit message

    self.history_count = self.history.count
    self.last_commit = history.first.to_s
    self.save
  end

  def repo
    return @repo if defined?(@repo) && !@repo.nil?
    @repo = self.campaign.repo
  end

end
