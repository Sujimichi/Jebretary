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
    #raise params.inspect
    @craft = Craft.find(params[:id])
    @campaign = @craft.campaign
    history = @craft.history

    commit = history.select{|h| h.sha.eql?(params[:sha_id])}.first if params[:sha_id]   
    if params[:update_message]
      #only attempt update to repo commit message if there are no untracked changes anywhere in the campaigns repo,
        
      if @campaign.nothing_to_commit?
        @craft.commit_message = params[:update_message] #message may not be saved, but is set so that validations can be used to checks its ok to write to repo.
        if @craft.valid? #run validations
          @craft.change_commit_message(commit, params[:update_message]) #update the message to the repo
          if commit.eql?(history.first) #in the case where this is the current commit then 
            @craft.commit_message = nil #set the commit message to nil it has been written to the repo
          else
            @craft.reload #if not then reload the craft to restore the commit message to how it was before being used in the validation
          end         
        end
      else
        #if there are untracked changes in the repo the message is cached on the craft object, to be written to the repo later.
        @craft.commit_message = params[:update_message] if commit.to_s.eql?(history.first.to_s)
      end
      @craft.save if @craft.valid?
      @errors = {:update_message => @craft.errors} unless @craft.errors.empty?
    end

    @craft.revert_to commit, :commit => params[:commit_revert].eql?("true") if params[:revert_craft]
    @craft.recover if @craft.deleted? && params[:recover_deleted]
    @craft.commit if params[:force_commit]

    if params[:move_copy]
      campaigns = Campaign.find(params[:move_copy_to_select])
      if params[:commit].downcase.eql?("copy")
        campaigns.each{|campaign| @craft.move_to campaign, :replace => true, :copy => true}       
      elsif params[:commit].downcase.eql?("move")
        campaigns.each{|campaign| @craft.move_to campaign, :replace => true }
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
end
