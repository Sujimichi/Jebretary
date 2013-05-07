class CampaignsController < ApplicationController

  def index
    respond_to do |f|
      f.js{
        instance = Instance.find(params[:instance_id])
        raise "couldn't find instance" unless instance && instance.is_a?(Instance)
        @campaigns = instance.campaigns
        #return render(:partial => 'campaigns/list', :locals => {:campaigns => campaigns})
      }
      f.html{}
    end
  end
end
