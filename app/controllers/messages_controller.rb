class MessagesController < ApplicationController

  respond_to :js

  def edit
    respond_to do |f|
      f.js {
        @craft = Craft.find(params[:id])
        @is_changed = @craft.is_changed?    
        @commit = @craft.repo.gcommit(params[:sha_id])
        @commit = "most_recent" if @commit.nil?
        @commit_messages = @craft.commit_messages
      }
    end
  end

  def update
    respond_to do |f|
      f.js {
        @craft = Craft.find(params[:id])
        latest_commit = @craft.history(:limit => 1).first

        commit = params[:sha_id]

        #change sha_id from "most_recent" if the craft no longer has untracked changes.
        #this is to catch the situation where the user started writting a commit message on a craft with untracked changes 
        #and while they where writting the craft got automatically tracked.         
        commit = latest_commit if params[:sha_id].eql?("most_recent") && !@craft.is_changed?

        params[:update_message].gsub!("\n","<br>") #replace new line tags with line break tags (\n won't commit to repo)

        unless latest_commit.message == params[:update_message]
          messages = @craft.commit_messages
          messages[commit] = params[:update_message]
          @craft.commit_messages = messages
          @craft.save! if @craft.valid? 
          @errors = {:update_message => @craft.errors.full_messages.join} unless @craft.errors.empty?      
        end
      }
    end
  end

end
