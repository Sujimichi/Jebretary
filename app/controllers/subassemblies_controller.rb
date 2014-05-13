class SubassembliesController < ApplicationController
  respond_to :html, :js

  def show
    respond_with(@subassembly) do |f|
      f.html{
        @subassembly = Subassembly.find(params[:id])  
      }
      f.js{
        ensure_no_db_lock do         
          @subassembly = Subassembly.find(params[:id])  
          @history = @subassembly.history
        end      
      }
    end
  end

  def edit
    respond_with(@subassembly) do |f|
      f.js{
        @subassembly = Subassembly.find(params[:id])  
        history = @subassembly.history
        @commit = history.select{|commit| commit.to_s.eql?(params[:sha_id])}.first
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
      message = "Your subassembly has been reverted."
    end
    #if @subassembly.deleted? && params[:recover_deleted]
    #  message = "Your subassembly has been recovered.</br>You can now load it in KSP"
    #  @subassembly.recover 
    #end
    
    redirect_to :back, :notice => message
  end

end
