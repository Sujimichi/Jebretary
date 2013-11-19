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
          @repo = @campaign.repo 
          @repo_status = @repo.status

          @new_and_changed = @campaign.new_and_changed(@repo_status)          
          @current_project = @campaign.last_changed_craft(@new_and_changed)
          @current_project_history = @current_project.history(@repo)

          @saves = @campaign.save_history(@repo)
          @most_recent_commit = @campaign.latest_commit(@current_project, @saves, @new_and_changed)

          @deleted_craft_count = @campaign.craft.where(:deleted => true).count
          @craft_for_list = @campaign.craft.group_by{|g| g.craft_type}.sort.reverse

          @campaign_commit_messages = @campaign.commit_messages
          @current_project_commit_messages = @current_project.commit_messages

          #this really needs optimising for windows.  
          #Takes around 4000ms on windows (in production mode) which is unacceptable, on Linux (in the slower dev mode) it takes ~200ms

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
    params[:update_message].gsub!("\n","<br>") #replace new line tags with line break tags (\n won't commit to repo)
    unless params[:update_message] == commit.message
      messages = @campaign.commit_messages
      messages[commit] = params[:update_message]
      @campaign.commit_messages = messages
      @campaign.save! if @campaign.valid? 
      @errors = {:update_message => @campaign.errors.full_messages.join} unless @campaign.errors.empty?          
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
