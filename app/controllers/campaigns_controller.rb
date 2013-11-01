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

  def update
    @campaign = Campaign.find(params[:id])
    commit = @campaign.repo.gcommit(params[:sha_id])
    messages = @campaign.commit_messages
    messages[commit] = params[:update_message]
    @campaign.commit_messages = messages
    @campaign.save! if @campaign.valid? 
    @errors = {:update_message => @campaign.errors.full_messages.join} unless @campaign.errors.empty?          
  end

  def destroy
    @campaign = Campaign.find(params[:id])
    @campaign.destroy
    respond_to do |format|
      format.html { redirect_to :back }
    end
  end
  
end
