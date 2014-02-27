class CraftsController < ApplicationController

  respond_to :html, :js

  def index
    if params.include?(:campaign_id)
      campaign = Campaign.find(params[:campaign_id])
      @craft = campaign.craft
    else 
      @craft = Craft.all
    end
    respond_with(@craft) do |f|      
      f.js { }
      f.html { }
    end    
  end

  def show
    respond_with(@craft) do |f|
      f.html{
        @craft = Craft.find(params[:id])
      }
      f.js{
        ensure_no_db_lock do         
        @craft = Craft.find(params[:id])
        @history = @craft.history
        end
      }
    end
  end

  def edit
    respond_with(@craft) do |f|
      f.html{
        @craft = Craft.find(params[:id])
        @sha_id = params[:sha_id]
        @commit = @craft.repo.gcommit(@sha_id)
        @is_changed = @craft.is_changed?
        history = @craft.history

        unless @craft.deleted?          
          @revert_to_version = history.reverse.map{|h| h.sha_id}.index(@commit.sha_id) + 1
          @current_version = @craft.history_count
        end
        @latest_commit = history.first
        @return_to = params[:return_to]       
      }
    end
  end

  def update
    @craft = Craft.find(params[:id])
    @campaign = @craft.campaign

    if params[:revert_craft]
      @craft.revert_to params[:sha_id], :commit => params[:commit_revert].eql?("true") 
      message = "Your craft has been reverted.</br>Reload it in the KSP editor"
    end
    if @craft.deleted? && params[:recover_deleted]
      message = "Your craft has been recovered.</br>You can now load it in KSP"
      @craft.recover 
    end

    if params[:force_commit]
      @craft.commit :m => @craft.commit_messages["most_recent"]
      @craft.remove_message_from_temp_store "most_recent"
      @craft.save
    end
    respond_with(@craft) do |f|
      f.html{        
        if params[:return_to] && params[:return_to] == "campaign"
          redirect_to @campaign, :notice => message.html_safe
        else
          redirect_to @craft, :notice => message.html_safe
        end
      }
      f.js{}
    end
  end

  def destroy
    @craft = Craft.find(params[:id])
    @craft.delete_craft
    redirect_to @craft.campaign
  end
end
