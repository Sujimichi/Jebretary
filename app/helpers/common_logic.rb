module CommonLogic

  #crafts_campaign= allows the campaign to be passed in and held in instance var if the campaign has already been loaded from the DB
  def crafts_campaign= campaign
    @campaign = campaign
  end
  #returns a cached instance of the campaign
  def crafts_campaign
    return @campaign if defined?(@campaign) && !@campaign.nil?
    crafts_campaign = self.campaign
  end

  def repo
    return @repo if defined?(@repo) && !@repo.nil?
    @repo = crafts_campaign.repo
  end


  def file_path campaign_path = crafts_campaign.path
    File.join([campaign_path, self.local_path])
  end
  alias path file_path



  #deleted the craft file and marks the craft object as being deleted.
  def delete_file
    return unless File.exists?(self.file_path) && !self.deleted?
    File.delete(self.file_path)
    self.deleted = true
    self.commit :dont_sync => true
  end


end
