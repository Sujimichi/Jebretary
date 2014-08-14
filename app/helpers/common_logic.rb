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

  def reset_cache
    @repo = nil
    @campaign = nil
    return self
  end


  def file_path campaign_path = crafts_campaign.path
    File.join([campaign_path, self.local_path])
  end
  alias path file_path



  #deleted the craft file and marks the craft object as being deleted.
  def delete_file
    return unless File.exists?(self.file_path) && !self.deleted?
    File.delete(self.file_path)

    message = "#{self.name} has been deleted"
    
    #remove reference to this object in the other objects it is sync'd with
    unless self.sync[:with].blank?
      objects = self.class.where(:name => self.name, :campaign_id => self.sync_targets)
      objects.each do |obj|
        obj.sync = {:with => obj.sync[:with].select{|id| id != self.campaign_id} }
        obj.save
      end
      self.sync = {:with => []} # remove all sync ids from this object
      message << " and the #{self.class.to_s.downcase} it was sync'd with no longer reference it"
    end

    self.deleted = true   
    self.commit :dont_sync => true
    message
  end


end
