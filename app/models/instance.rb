class Instance < ActiveRecord::Base
  attr_accessible :full_path

  def path
    p = JSON.parse(self.full_path)
    File.join(*p)
  end
end

