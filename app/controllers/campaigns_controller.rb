class CampaignsController < ApplicationController
   
  respond_to :html, :js

  def index
    @campaigns = Campaign.all
    respond_with(@campaigns) do |f|
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

  def destroy
    @campaign = Campaign.find(params[:id])
    @campaign.destroy
    respond_to do |format|
      format.html { redirect_to :back }
    end
  end
  
end
