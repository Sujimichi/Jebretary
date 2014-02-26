class Craft < ActiveRecord::Base
  include CommitMessageChanger

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

  #crafts_campaign= allows the campaign to be passed in and held in instance var if the campaign has already been loaded from the DB
  def crafts_campaign= campaign
    @campaign = campaign
  end

  #returns a cached instance of the campaign
  def crafts_campaign
    return @campaign if defined?(@campaign) && !@campaign.nil?
    craft_campaign = self.campaign
  end

  def repo
    return @repo if defined?(@repo) && !@repo.nil?
    @repo = crafts_campaign.repo
  end
  def reset_repo_cache
    @repo = nil
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

  #takes a block to run and while the block is being run the persistence_checksum on the craft campaign is set to 'skip'
  #this means that the campaign will not be processed by the background monitor while the blocks actions are being carried out.
  def dont_process_campaign_while &blk
    self.campaign.update_attributes(:persistence_checksum => "skip") #unless self.campaign.persistence_checksum.eql?("skip")
    yield
    self.campaign.update_persistence_checksum
  end


  #stage the changes and commits the craft. simply returns if there are no changes.
  def commit args = {}
    #dont_process_campaign_while do 
      action = :deleted if self.deleted?
      action ||= self.is_new? ? :added : (self.is_changed? ? :updated : :nothing_to_commit)     
      
      unless action.eql?(:nothing_to_commit)
        message = "#{action} #{name}"
        message = args[:m] if args[:m]      
        if action.eql?(:deleted)
          repo.remove(self.file_name)
          self.history_count += 1
        else
          repo.add(self.file_name)
        end

        active_message = self.commit_messages[:latest]
        message << " #{active_message.gsub(message,"")}" unless self.deleted? || active_message.blank? || active_message.eql?(message)
        self.remove_message_from_temp_store(:latest)
        
        repo.commit(message)
        self.last_commit = repo.log.first.to_s
      end


      unless action.eql?(:deleted)    
        self.part_count ||= 1
        self.part_count += 1 #temp till part count is implemented
        self.history_count = self.history.size
        self.history_count = 1 if self.history_count.eql?(0)        
      end
      self.save if self.changed?
      return action
    #end
  end


  #revert the craft to a previous commit
  def revert_to commit, options = {:commit => true}
    dont_process_campaign_while do 
      repo = self.campaign.repo
      index = history.reverse.map{|c| c.to_s}.index(commit.to_s) + 1
      repo.checkout_file(commit, file_name)
      if options[:commit]
        begin
          m = "reverted #{name} to V#{index}"
          repo.commit(m)
        rescue
        end
        update_history_count
      end
      cms = self.commit_messages
      cms["most_recent"] = "reverted #{name} to V#{index}"
      self.commit_messages = cms
      self.save!
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


  def commit_messages
    messages = super
    return {} if messages.blank?
    h = JSON.parse(messages)
    HashWithIndifferentAccess.new(h)
  end

  def commit_messages= messages
    messages = messages.to_json unless messages.blank?
    messages = nil if messages.blank?
    super messages
  end

  def replace_most_recent_key_with_latest_commit_sha
    msgs = commit_messages
    return unless msgs.has_key?("most_recent")
    m = msgs["most_recent"]
    msgs.delete("most_recent")
    msgs[history.first] = m
    self.commit_messages = msgs
    self.save
  end

  def remove_message_from_temp_store key
    messages = self.commit_messages
    messages.delete(key)
    commit_messages = messages
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
