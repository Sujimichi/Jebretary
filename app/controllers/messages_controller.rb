class MessagesController < ApplicationController

  respond_to :js

  def edit
    # ({"commit_message"=>"true", "save_type"=>"quicksave", "sha_id"=>"c6c166155280f7ea8ae49451b716529686933e1f", "action"=>"edit", "controller"=>"messages", "id"=>"1"}):

    respond_to do |f|
      f.js {

        if params[:save_type]
          @object = Campaign.find(params[:id])
          @commit = @object.repo.gcommit(params[:sha_id])
          @message = @commit.message
          @commit_messages = @object.commit_messages
          stored_message = @commit_messages[@commit.to_s]
          @message = stored_message if stored_message
          @is_changed = false
          @holder= "#edit_save_holder"
        else
          @object = Craft.find(params[:id])
          @is_changed = @object.is_changed?    
          @commit = @object.repo.gcommit(params[:sha_id])
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
        elsif params[:object_class].eql?("Campaign")
          @object = Campaign.find(params[:id])
          @holder = "#edit_save_holder"
        else
          @errors = {:update_message => "failed to find object"}
          return
        end
      
        commit = @object.repo.gcommit(params[:sha_id])
        existing_message = commit.message

        if params[:sha_id] == "most_recent" #this only happens when @object is a craft
          commit = params[:sha_id]
  
          #change sha_id from "most_recent" if the craft no longer has untracked changes.
          #this is to catch the situation where the user started writting a commit message on a craft with untracked changes 
          #and while they where writting the craft got automatically tracked.         
          commit = @object.history(:limit => 1).first if !@object.is_changed?
          #if the commit is the latest commit, set existing_message to it's message, otherwise (for most_recent) use ""
          existing_message = commit.respond_to?(:message) ? commmit.message : ""
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
