class Craft < ActiveRecord::Base
  include CommitMessageChanger
  include CommonLogic
  include RepoObject

  attr_accessible :name, :craft_type, :deleted, :part_count, :history_count, :last_commit, :commit_messages, :part_data, :sync
  belongs_to :campaign

  require 'active_support/builder'

  validates :commit_messages, :git_compatible => true

  #
  ## - Instance Methods
  ###

  #retun the path to the .craft file, form the root of the repo.
  def local_path
    "Ships/#{craft_type.upcase}/#{name}.craft"
  end
  alias file_name local_path 

  def file_path
    File.join([self.campaign.path, self.local_path])
  end
  alias path file_path

  #to be repalced with attribute to enable optional tracking of craft.
  def track?
    true
  end

  def parts args = {:load_data => false, :read_file => true}
    @parts = nil if args[:load_data]
    return @parts if defined?(@parts) && !@parts.nil?
    @parts = CraftFileReader.new(self, args)
  end

  def update_part_data
    return false if self.deleted?
    parts.locate_in self.crafts_campaign.campaigns_instance.parts
    data = {:parts => parts.found, :missing_parts => parts.missing, :stock => parts.stock?, :mods => parts.mods}
    self.part_data = data
    true
  end  

  def part_data
    data = super
    data = JSON.parse(data) unless data.blank?
    data ||= {}
    HashWithIndifferentAccess.new(data)
  end

  def part_data= data
    data = data.to_json unless data.nil?
    super(data)
  end

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


  alias new_craft? is_new?
  alias changed_craft? is_changed?

  
  def dont_process_campaign_while &blk
    self.campaign.update_attributes(:persistence_checksum => "skip") #unless self.campaign.persistence_checksum.eql?("skip")
    yield
    self.campaign.update_persistence_checksum
  end


  #stage the changes and commits the craft. simply returns if there are no changes.
  def commit args = {}
    action = :deleted if self.deleted?
    action ||= self.is_new? ? :added : (self.is_changed? ? :updated : :nothing_to_commit)     
    args[:skip_part_data] ||= false
    
    unless action.eql?(:nothing_to_commit)
      message = "#{action} #{name}"
      message = args[:m] if args[:m]      
      if action.eql?(:deleted)
        repo.remove(self.file_name)
        self.history_count += 1
      else
        repo.add(self.file_name)
      end

      active_message = self.commit_messages[:most_recent]
      message = "#{active_message.gsub(message,"")}" unless self.deleted? || active_message.blank? || active_message.eql?(message)
      self.remove_message_from_temp_store(:most_recent) unless active_message.blank?
      
      repo.commit(message)
      self.last_commit = repo.log(self.local_path, :limit => 1).first.to_s
    end
    unless action.eql?(:deleted)    
      self.part_count = parts.count
      self.part_count ||= 0      
      update_part_data unless args[:skip_part_data]

      self.history_count = self.history.size
      self.history_count = 1 if self.history_count.eql?(0)        
    end
    self.save if self.changed?
  
    synchronize unless args[:dont_sync] || self.attributes["sync"].blank? #rather than calling sync.blank? to skip the JSON parsing step.
    return action
  end

  def replace_most_recent_key_with_latest_commit_sha
    msgs = commit_messages
    return unless msgs.has_key?("most_recent")
    m = msgs["most_recent"]
    msgs.delete("most_recent")
    msgs[history(:linit => 1).first] = m
    self.commit_messages = msgs
    self.save
  end

  #deleted the craft file and marks the craft object as being deleted.
  def delete_craft
    return unless File.exists?(self.file_path) && !self.deleted?
    File.delete(self.file_path)
    self.deleted = true
    self.commit :dont_sync => true
  end

  def move_to other_campaign, opts = {}
    target_path = File.join([other_campaign.path, self.file_name])
    return false if File.exists?(target_path) && !opts[:replace]
    file = File.open(self.file_path, 'r'){|f| f.readlines}.join
    File.delete(self.file_path) unless opts[:copy]
    File.open(target_path,'w'){|f| f.write(file)}
    if opts[:copy] || opts[:replace]
      existing_craft = other_campaign.craft.where(:name => self.name).first
      if existing_craft
        attrs = self.attributes.clone
        [:id, :created_at, :updated_at, :campaign_id, :part_data, :sync].each{|at| attrs.delete(at.to_s)}
        attrs[:part_data] = self.part_data
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
