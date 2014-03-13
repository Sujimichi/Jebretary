class Craft < ActiveRecord::Base
  include CommitMessageChanger
  include CommonLogic

  attr_accessible :name, :craft_type, :deleted, :part_count, :history_count, :last_commit
  belongs_to :campaign

  require 'active_support/builder'

  validates :commit_messages, :git_compatible => true

  #
  ## - Instance Methods
  ###

  #retun the path to the .craft file, form the root of the repo.
  def file_name
    "Ships/#{craft_type.upcase}/#{name}.craft"
  end

  def file_path
    File.join([self.campaign.path, self.file_name])
  end

  #to be repalced with attribute to enable optional tracking of craft.
  def track?
    true
  end

  def parts args = {:load_data => false, :read_file => true}
    @parts = nil if args[:load_data]
    return @parts if defined?(@parts) && !@parts.nil?
    @parts = CraftFileReader.new(self, args)
  end

  def part_data
    data = super
    data = JSON.parse(data) unless data.blank?
    data ||= {}
    HashWithIndifferentAccess.new(data)
  end

  def part_data= data
    data = data.to_json
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

  #return true if the craft is not yet in the repo
  def is_new?
    return false if deleted?
    repo.untracked.include?("Ships/#{craft_type.upcase}/#{name}.craft")
  end
  alias new_craft? is_new?

  #return true if the craft is in the repo and has changes.  If not in repo it returns nil.
  def is_changed? 
    return nil if is_new? 
    return false if deleted?
    repo.changed.include?("Ships/#{craft_type.upcase}/#{name}.craft")
  end
  alias changed_craft? is_changed?

  
  def update_history_count
    self.update_attributes(:history_count => self.history.size)   
  end

  #return the commits for the craft (most recent first)
  def history args = {:limit => false}
    return [] if is_new? || deleted?
    begin
      logs = repo.log(file_name, :limit => args[:limit])
    rescue
      []
    end
  end

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
      self.last_commit = repo.log.first.to_s
    end
    unless action.eql?(:deleted)    
      self.part_count = parts.count
      self.part_count ||= 0      
      update_part_data unless args[:skip_part_data]

      self.history_count = self.history.size
      self.history_count = 1 if self.history_count.eql?(0)        
    end
    self.save if self.changed?
    return action
  end


  def update_part_data
    parts.locate_in self.crafts_campaign.instance.parts
    data = {:parts => parts.found, :missing_parts => parts.missing, :stock => parts.stock?, :mods => parts.mods}
    self.part_data = data
  end

  #revert the craft to a previous commit
  def revert_to commit, options = {:commit => true}
    camp = self.campaign
    camp.dont_process_while do 
      repo = camp.repo
      index = history.reverse.map{|c| c.to_s}.index(commit.to_s) + 1
      repo.checkout_file(commit, file_name)
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

  def recover
    deleting_commit = self.last_commit
    commit = repo.gcommit(deleting_commit).parent
    repo.checkout_file(commit, self.file_name)
    repo.commit("recovered #{name}")
    self.deleted = false
    self.history_count = self.history.size
    self.last_commit = repo.log.first.to_s
    self.save
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
    self.commit
  end

  def move_to campaign, opts = {}
    target_path = File.join([campaign.path, self.file_name])
    return false if File.exists?(target_path) && !opts[:replace]
    file = File.open(self.file_path, 'r'){|f| f.readlines}.join
    File.delete(self.file_path) unless opts[:copy]
    File.open(target_path,'w'){|f| f.write(file)}
    if opts[:copy] || opts[:replace]
      existing_craft = campaign.craft.where(:name => self.name).first
      existing_craft.destroy if existing_craft
      self.update_attributes(:deleted => true) unless opts[:copy]
      cpy = campaign.craft.create!(:name => self.name, :craft_type => self.craft_type)
      campaign.update_attributes(:persistence_checksum => nil)
    else
      self.campaign_id = campaign.id
      self.save
    end
    true
  end

end
