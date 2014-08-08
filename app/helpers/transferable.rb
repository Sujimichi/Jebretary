module Transferable

    
  def move_to other_campaign, opts = {}
    target_path = File.join([other_campaign.path, self.file_name])
    return false if File.exists?(target_path) && !opts[:replace]
    file = File.open(self.file_path, 'r'){|f| f.readlines}.join
    File.delete(self.file_path) unless opts[:copy]
    File.open(target_path,'w'){|f| f.write(file)}
    if opts[:copy] || opts[:replace]
      
      existing_craft = other_campaign.send({
        "Craft" => "craft", "Subassembly" => "subassemblies"
      }[self.class.to_s]).where(:name => self.name).first
      
      if existing_craft
        attrs = self.attributes.clone
        [:id, :created_at, :updated_at, :campaign_id, :part_data, :sync].each{|at| attrs.delete(at.to_s)}
        attrs[:part_data] = self.part_data if self.is_a? Craft
        existing_craft.update_attributes(attrs)
        cpy = existing_craft
      else
        cpy = self.dup
        cpy.campaign = other_campaign
        cpy.save
      end

      self.update_attributes(:deleted => true) unless opts[:copy]

      other_campaign.update_attributes(:persistence_checksum => nil)
    else
      self.campaign_id = other_campaign.id
      self.save
    end

    return cpy || self
  end


  #takes either a Campaign object or an id for a campaign and adds it to the crafts sync[:with] list
  def sync_with campaign
    campaign_id = campaign.id if campaign.is_a?(Campaign) 
    campaign_id ||= campaign

    sync_list = self.sync
    sync_list[:with] ||= []
    sync_list[:with] << campaign_id
    self.sync = sync_list
    self.save
  end

  def sync
    sync_list = super
    begin
      HashWithIndifferentAccess.new JSON.parse(sync_list)
    rescue
      {}
    end
  end

  def sync= sync_list
    super(sync_list.to_json)
  end

  def synchronize
    return false if sync[:with].nil?
    sync[:with].each do |campaign_id|
      next if campaign_id.eql?(self.campaign_id) #don't try to sync to itself!
      
      cpy = self.move_to(Campaign.find(campaign_id), :copy => true, :replace => true) #actual copy step (copies craft file ensures craft object is present)
      cpy.commit :m => self.history(:limit => 1).first.message, :dont_sync => true    #commit the updated craft, passing in the commit message for this craft
                                                                                      #dont_sync is true to prevent a infinate loop, only place dont_sync => true is used
      cpy.sync = {:with => [self.sync[:with], self.campaign_id].flatten}              #update the sync_list on the remote craft
      cpy.save if cpy.changed?
    end
  end

  def sync_targets
    sync_with_campaigns = self.sync[:with]
    return [] if sync_with_campaigns.blank? #no sync targets
    campaigns = Campaign.where(:id => sync_with_campaigns) #select the campaigns from the DB, :where rather than find as some ids might be wrong (ie if a campaign was removed)
    return campaigns if campaigns.size.eql?(sync_with_campaigns) #return the found campaigns, if there is the same number as expected from the sync[:with] ids
    self.sync = {:with => campaigns.map{|c| c.id} } #update/fix the sync[:with] ids if there was a discrepency.
    self.save
    campaigns
  end


end
