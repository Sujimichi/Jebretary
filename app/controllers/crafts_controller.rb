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
    @craft = Craft.find(params[:id])
    unless @craft.deleted?
      @sha_id = params[:sha_id]
      history = @craft.history
      @commit = history.select{|commit| commit.sha == @sha_id}.first
      @revert_to_version = history.reverse.index(@commit) + 1
    end
    @return_to = params[:return_to]
    respond_with(@craft) do |f|
      f.html{}
      f.js {
        
      }
    end
  end

  def update
    @craft = Craft.find(params[:id])
    history = @craft.history

    commit = history.select{|h| h.sha.eql?(params[:sha_id])}.first if params[:sha_id]   
    if params[:update_message]
      @craft.commit_message = params[:update_message] if commit.eql?(history.first)
      if @craft.save || !commit.eql?(history.first)
        @craft.change_commit_message commit, params[:update_message] 
      else
        @errors = {:update_message => @craft.errors}
      end
    end
    @craft.revert_to commit, :commit => params[:commit_revert].eql?("true") if params[:revert_craft]
    @craft.recover if @craft.deleted? && params[:recover_deleted]
    @craft.commit if params[:force_commit]

    respond_with(@craft) do |f|
      f.html{
        if params[:return_to] && params[:return_to] == "campaign"
          redirect_to @craft.campaign
        else
          redirect_to @craft
        end
      }
      f.js {}
    end

  end
end
