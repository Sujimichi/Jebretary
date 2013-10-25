class SavesController < ApplicationController
   
  respond_to :js, :html

  def index
    @campaign = Campaign.find(params[:id])
  end

  def edit
    @campaign = Campaign.find(params[:id])
    respond_with(@campaign) do |f|
      f.js{
        @save_type = params[:save_type]
        @commit = @campaign.repo.gcommit(params[:sha_id])
        @version = @campaign.save_history[@save_type.to_sym].map{|c| c.to_s}.index(@commit.to_s)
      }
    end    
  end

  def update
    campaign = Campaign.find(params[:id])
    commit = campaign.repo.gcommit(params[:sha_id])
    campaign.revert_save params[:save_type], commit, :commit => true
    redirect_to :back, :notice => "Your #{params[:save_type]}.sfs file has been reverted"
  end
end
