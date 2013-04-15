class Campaign < ActiveRecord::Base
  attr_accessible :instance_id, :name
  belongs_to :instance
end
