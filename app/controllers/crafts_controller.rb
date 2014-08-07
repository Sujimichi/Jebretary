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
        Rails.cache.delete("state_stamp")
        @craft = Craft.find(params[:id])       
        unless @craft.deleted?
          @craft.update_part_data 
          @craft.save if @craft.changed?
          @parts = @craft.parts :load_data => true, :read_file => false
          @part_for_list = @parts.found.group_by{|part| part[:name]}.to_a.sort_by{|part| part[1][0][:mod].downcase}.map{|p| [p[0], p[1].sort_by{|pt| pt[:name].downcase} ] }.in_groups(2)      
        end        
      }
      f.js{
        if params[:open_part_folder]
          @craft = Craft.find(params[:id])
          path = File.join([@craft.campaign.instance.path, params[:open_part_folder]])

          if path.match(/.cfg$/)
            path = path.split("/")
            path.pop
            path = File.join(path)
          end

          begin 
            if RUBY_PLATFORM =~ /mswin|mingw|cygwin/
              `start explorer.exe #{path.split("/").join("\\")}` #this has to be in windows format which is not what File.join returns 
            else
              `nautilus #{path}`
            end
          rescue
          end
          return render :text => "done"

        else

          ensure_no_db_lock do         
            @craft = Craft.find(params[:id])
            campaign = @craft.campaign

            state = [campaign.repo.log(:limit => 1).first.to_s, campaign.has_untracked_changes?].to_json
            state = Digest::SHA256.hexdigest(state)

            if Rails.cache.read("state_stamp") != state || !Rails.cache.read("last_controller").eql?("CraftsController") 
              @history = @craft.history  
              @sync_targets = @craft.sync_targets
            else
              return render :partial => "partials/no_update"
            end
            Rails.cache.write("state_stamp", state)

          end
        end
      }
    end
  end

  def edit
    respond_with(@craft) do |f|
      f.html{
        @craft = Craft.find(params[:id])
        @sha_id = params[:sha_id]
        history = @craft.history
        @commit = history.select{|c| c.to_s.eql?(@sha_id)}.first
        @is_changed = @craft.is_changed?
        

        unless @craft.deleted?          
          @revert_to_version = history.reverse.map{|h| h.sha_id}.index(@sha_id) + 1
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
