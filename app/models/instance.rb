class Instance < ActiveRecord::Base
  attr_accessible :full_path

  def path
    p = JSON.parse(self.full_path)
    File.join(*p)
  end


  def discover_campaigns
    ignored = ['.', '..', 'training', 'scenarios']
    dirs = Dir.entries(File.join(self.path, "saves"))
    dirs - ignored
  end

end

