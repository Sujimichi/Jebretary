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

        if params[:commit_message]
          @message = @commit.message
          @commit_messages = @campaign.commit_messages
          stored_message = @commit_messages[@commit.to_s]
          @message = stored_message if stored_message
        end
      }
    end    
  end

  def update
    campaign = Campaign.find(params[:id])
    if params[:sha_id]
      commit = campaign.repo.gcommit(params[:sha_id])
      campaign.revert_save params[:save_type], commit, :commit => true
      note = "Your #{params[:save_type]}.sfs file has been reverted"
    end
    if params[:revert_as_quicksave]
      campaign.persistent_to_quicksave 
      if params[:sha_id]
        note << " and the quicksave file has be replaced with the persistent file"
      else
        note = "Your quicksave file has been replaced with the persistent file"
      end
    end
    redirect_to :back, :notice => note
  end
end
