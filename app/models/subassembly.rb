class Subassembly < ActiveRecord::Base
  include RepoObject
  include CommonLogic
  include Transferable

  attr_accessible :campaign_id, :history_count, :name, :deleted, :last_commit
  belongs_to :campaign


  #retun the path to the .craft file, form the root of the repo.
  def local_path
    File.join(["Subassemblies", "#{self.name}.craft"])
  end
  alias file_name local_path 

  def commit args = {}
    @repo = args[:repo] if args.has_key?(:repo)
    action = :deleted if self.deleted?
    action ||= self.is_new? ? :added : (self.is_changed? ? :updated : :nothing_to_commit)     

    unless action.eql?(:nothing_to_commit)
      message = "#{action} subassembly: #{name}"
      message = args[:m] if args[:m]      
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
    synchronize unless args[:dont_sync] || self.attributes["sync"].blank? #rather than calling sync.blank? to skip the JSON parsing step.    
    return action
  end

  def move_to other_campaign, opts = {}
    Dir.mkdir( File.join([other_campaign.path, "Subassemblies"]) ) unless Dir.exist?(File.join([other_campaign.path, "Subassemblies"]))
    super other_campaign, opts
  end

end
