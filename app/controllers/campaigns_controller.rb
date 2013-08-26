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
    respond_with(@campaign) do |f|
      f.js{
        ensure_no_db_lock do 
          @campaign = Campaign.find(params[:id])
        end
      }
      f.html{
        @campaign = Campaign.find(params[:id])
      }
    end
  end
end
