class CampaignsController < ApplicationController
   
  respond_to :html, :js

  def index
    instance = Instance.find(params[:instance_id])
    @campaigns = instance.campaigns if instance
    @campaigns ||= Campaign.all

    respond_with(@campaigns) do |f|
      f.js{}
      f.html{}
    end
  end

  def show
    @campaign = Campaign.find(params[:id])
    respond_with(@campaign) do |f|
      f.js{}
      f.html{}
    end
  end
end
