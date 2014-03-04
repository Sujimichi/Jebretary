class LaunchController < ApplicationController
  #require 'assets/ksp'
  def index
    respond_to do |f|
      f.js { 
        running_instances = KSP.controller.find_running_instances
        if RUBY_PLATFORM =~ /mswin|mingw|cygwin/
          running_instances = running_instances..map{|i| i.executablepath.sub("\\KSP.exe","")}
          tracked_paths = Instance.all.map{|i| i.path.split("/").join("\\")}
          @instances = running_instances.select{|path| !tracked_paths.include?(path)}
        else
          @instances = running_instances
        end
      }
    end  
  end

  def show
    instance = Instance.find(params[:id])
    KSP.controller.start instance.path
    redirect_to :back
  end

  def edit
  end

  def destroy
  end

end

