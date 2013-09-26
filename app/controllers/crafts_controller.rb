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
      @current_version = @craft.history_count
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
    @campaign = @craft.campaign
    history = @craft.history

    if params[:sha_id] 
      commit = history.first if params[:sha_id].eql?("most_recent")
      commit ||= history.select{|h| h.sha.eql?(params[:sha_id])}.first 
    end


    @craft.revert_to commit, :commit => params[:commit_revert].eql?("true") if params[:revert_craft]
    @craft.recover if @craft.deleted? && params[:recover_deleted]
    @craft.commit if params[:force_commit]

    if params[:move_copy]
      campaigns = Campaign.find(params[:move_copy_to_select])
      unless campaigns.empty?
        campaigns.each{|campaign| @craft.move_to campaign, :replace => true, :copy => true} #for either copy or move perform the copy to all selected campaigns
        @craft.move_to(campaigns.last, :replace => true, :copy => false) if params[:commit].downcase.eql?("move") 
        #if it was a move, redo the move to the last campaign with copy=>false.  Using copy=>false for a group of campaigns won't work as the first one would 
        #delete the craft file and set the craft object as deleted.
      end
    end


    #updating commit message
    if params[:update_message]
      @craft.commit_message = params[:update_message] #message may not be saved, but is set so that validations can be used to check its ok to write to repo.
      if @craft.valid? #run validations

        if !system_monitor_running? && @craft.change_commit_message(commit, params[:update_message]) #update the message to the repo, or return false if unable to.
          #in the case where this is the current commit then set the commit message to nil as it has been written to the repo
          #if not then reload the craft to restore the commit message to how it was before being used in the validation       
          @craft.send *commit.eql?(history.first) ? ["commit_message=", nil] : ["reload"]   
        else
          #if there are untracked changes in the repo the message is cached on the craft object, to be written to the repo later.
          if commit.to_s.eql?(history.first.to_s)
            @craft.commit_message = params[:update_message] 
          else
            message = ["Could not update message at this time.  "]
            message << (system_monitor_running? ? "The repo is being written to, wait a couple seconds and try again." : "There are untracked changes in the repo, make sure everything is commited and try again.")

            @errors = {:update_message => message.join } 
            @craft.reload
          end
        end
        @craft.save if @craft.changed?
      else
        @errors = {:update_message => @craft.errors.full_messages.join} unless @craft.errors.empty?
      end
    end


    respond_with(@craft) do |f|
      f.html{
        if params[:return_to] && params[:return_to] == "campaign"
          redirect_to @campaign
        else
          @craft = campaigns.first.craft.where(:name => @craft.name).first if params[:move_copy] && params[:commit].downcase.eql?("move")
          redirect_to @craft
        end
      }
      f.js {}
    end

  end

  def destroy
    @craft = Craft.find(params[:id])
    @craft.delete_craft
    redirect_to @craft.campaign
  end
end
