class MessagesController < ApplicationController

  respond_to :js

  def edit
    respond_to do |f|
      f.js {

        if params[:save_type]
          @object = Campaign.find(params[:id])

          
          path = File.join([@object.path, "#{params[:save_type]}.sfs"])
          @commit = @object.repo.get_commit(:for => path, :sha_id => params[:sha_id]) #select commit (faster method)
          @commit ||= @object.repo.gcommit(params[:sha_id]) #select commit (slower method, if above didn't find it)

          @message = @commit.message
          @commit_messages = @object.commit_messages
          stored_message = @commit_messages[@commit.to_s]
          @message = stored_message if stored_message
          @is_changed = false
          @holder= "#edit_save_holder"
          @save_type = params[:save_type]
        else
          @object = Craft.find(params[:id])
          @is_changed = @object.is_changed?              
          @commit = @object.repo.get_commit(:for => @object.path, :sha_id => params[:sha_id]) #select commit (faster method)
          @commit ||= @object.repo.gcommit(params[:sha_id]) #select commit (slower method, if above didn't find it)
          @commit = "most_recent" if @commit.nil?
          @commit_messages = @object.commit_messages
          @holder = "#message_form_for_#{@commit.to_s}"
        end
      }
    end
  end

  def update
    respond_to do |f|
      f.js {         
        if params[:object_class].eql?("Craft")
          @object = Craft.find(params[:id])
          @holder = ".message_form"
          commit = @object.repo.get_commit(:for => @object.path, :sha_id => params[:sha_id]) unless params[:sha_id].eql?("most_recent")
        elsif params[:object_class].eql?("Campaign")
          @object = Campaign.find(params[:id])

          path = File.join([@object.path, "quicksave.sfs"])
          commit = @object.repo.get_commit(:for => path, :sha_id => params[:sha_id]) #attempt to fast find commit assuming its a quicksave
          if commit.nil?
            path.sub!("quicksave", "persistent") #if it wasn't a quicksave attempt to find it as a persistent (tends to be slower than for quicksaves)
            commit = @object.repo.get_commit(:for => path, :sha_id => params[:sha_id])
          end

          @holder = "#edit_save_holder"
        else
          @errors = {:update_message => "failed to find object"}
          return
        end

        #if fast find for commits didn't work, fallback on slower gcommit method
        commit = @object.repo.gcommit(params[:sha_id]) if commit.nil? && !params[:sha_id].eql?("most_recent")

        existing_message = commit.message if commit

        if params[:sha_id] == "most_recent" #this only happens when @object is a craft
          commit = params[:sha_id]
  
          #change sha_id from "most_recent" if the craft no longer has untracked changes.
          #this is to catch the situation where the user started writting a commit message on a craft with untracked changes 
          #and while they where writting the craft got automatically tracked.         
          commit = @object.history(:limit => 1).first if !@object.is_changed?
          #if the commit is the latest commit, set existing_message to it's message, otherwise (for most_recent) use ""
          existing_message = commit.respond_to?(:message) ? commit.message : ""
        end

        params[:update_message].gsub!("\n","<br>") #replace new line tags with line break tags (\n won't commit to repo)

        if existing_message != params[:update_message]
          messages = @object.commit_messages
          messages[commit] = params[:update_message]
          @object.commit_messages = messages
          @object.save! if @object.valid? 
          @errors = {:update_message => @object.errors.full_messages.join} unless @object.errors.empty?      
        end
      }
    end
  end
end
