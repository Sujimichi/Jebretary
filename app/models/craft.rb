class Craft < ActiveRecord::Base
  attr_accessible :name

  def self.identify_craft_in campaign
    dir = File.join(campaign.instance.path, "saves", campaign.name, "Ships")
    Dir.chdir(dir)
    {
      :vab => Dir.glob("VAB/*.craft").map{|craft| craft.gsub("VAB/", "")}, 
      :sph => Dir.glob("SPH/*.craft").map{|craft| craft.gsub("SPH/", "")}
    }
  end
end
