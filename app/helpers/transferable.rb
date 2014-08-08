module Transferable


  #move_to can either move or copy a craft.
  # move_to campaign #> will move the craft, assuming that one of the same name doesn't already exist in the target campaign
  # move_to campaign, :replace => true #>overwites the existing craft (if there is one) in the target campaign
  # move_to campaign, :copy => true   #> keeps the current craft in place and creates a new on in the target campaign
  # move_to campaign, :copy => true, :replace => true #do reall have to explain.
  #
  #after moving or copying the moved/copied craft will be committed.  A custom commit message can be passed in with :m, otherwise default ones will be used
  # move_to campaign, :copy => true, :replace => true, :m => "wite this as the commit message"
  def move_to other_campaign, args = {}
    target_path = File.join([other_campaign.path, self.file_name])
    return false if File.exists?(target_path) && !args[:replace]

    file = File.open(self.file_path, 'r'){|f| f.readlines}.join
    File.delete(self.file_path) unless args[:copy]
    File.open(target_path,'w'){|f| f.write(file)}
    
    if args[:copy] || args[:replace]
      
      existing_craft = other_campaign.send({
        "Craft" => "craft", "Subassembly" => "subassemblies"
      }[self.class.to_s]).where(:name => self.name).first
      
      if existing_craft
        message = "replaced by craft from #{crafts_campaign.instance.name} - #{crafts_campaign.name}"
        attrs = self.attributes.clone
        [:id, :created_at, :updated_at, :campaign_id, :part_data, :sync].each{|at| attrs.delete(at.to_s)}
        attrs[:part_data] = self.part_data if self.is_a? Craft
        existing_craft.update_attributes(attrs)
        object = existing_craft        
      else
        message = "copied from #{crafts_campaign.instance.name} - #{crafts_campaign.name}"
        object = self.dup
        object.campaign = other_campaign
        object.save
      end

      self.update_attributes(:deleted => true) unless args[:copy]

      other_campaign.update_attributes(:persistence_checksum => nil)
    else
      message = "moved from #{crafts_campaign.instance.name} - #{crafts_campaign.name}"
      self.campaign_id = other_campaign.id
      self.save
      object = self
    end

    message = args[:m] if args.has_key?(:m)

    object.reset_cache.commit :m => message, :dont_sync => true  #dont_sync is true to prevent infinate looping

    return object
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
      cpy = self.move_to(                               #copies craft file and ensurecraft object is present
        Campaign.find(campaign_id),                     
        :copy => true, :replace => true,                
        :m => self.history(:limit => 1).first.message   #move_to will commit the updated craft, using the lastest commit message for this craft
      )                                                                                       
      cpy.sync = {:with => [self.sync[:with], self.campaign_id].flatten}  #update the sync_list on the remote craft
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
