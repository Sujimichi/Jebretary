class Craft < ActiveRecord::Base
  include CommitMessageChanger
  include RepoObject
  include CommonLogic
  include Transferable

  attr_accessible :name, :craft_type, :deleted, :part_count, :history_count, :last_commit, :commit_messages, :part_data, :sync
  belongs_to :campaign

  require 'active_support/builder'

  validates :commit_messages, :git_compatible => true


  #retun the path to the .craft file, form the root of the repo.
  def local_path
    "Ships/#{craft_type.upcase}/#{name}.craft"
  end
  alias file_name local_path 


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


end
