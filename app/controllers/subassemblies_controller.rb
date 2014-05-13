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

end
