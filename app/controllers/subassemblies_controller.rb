class SubassembliesController < ApplicationController
  respond_to :html, :js

  def show
    respond_with(@subassembly) do |f|
      f.html{
        @subassembly = Subassembly.find(params[:id])  
        Rails.cache.delete("state_stamp")
      }
      f.js{
        ensure_no_db_lock do 
          @subassembly = Subassembly.find(params[:id])  
          campaign = @subassembly.campaign
          state = [campaign.repo.log(:limit => 1).first.to_s, campaign.has_untracked_changes?].to_json
          state = Digest::SHA256.hexdigest(state)

          if Rails.cache.read("state_stamp") != state || !Rails.cache.read("last_controller").eql?("SubassembliesController") 
            @history = @subassembly.history
          else
            return render :partial => "partials/no_update"
          end
          Rails.cache.write("state_stamp", state)
        end      
      }
    end
  end

  def edit
    respond_with(@subassembly) do |f|
      f.js{
        @subassembly = Subassembly.find(params[:id])  
        @commit = @subassembly.campaign.repo.get_commit(:for => @subassembly.path, :sha_id => params[:sha_id])
        @versions_ago = @subassembly.history_count - params[:version].to_i
        @sha_id = params[:sha_id]
      }
    end
  end

  def update
    @subassembly = Subassembly.find(params[:id])
    @campaign = @subassembly.campaign

    if params[:revert_subassembly]
      @subassembly.revert_to params[:sha_id], :commit => true
      message = "Subassembly has been reverted."
    end
    if @subassembly.deleted? && params[:recover_deleted]
      message = "Subassembly has been recovered"
      @subassembly.recover 
    end
    
    redirect_to :back, :notice => message
  end

end
