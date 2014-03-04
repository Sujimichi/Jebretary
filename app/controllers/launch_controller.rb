class LaunchController < ApplicationController
  #require 'assets/ksp'
  def index
    respond_to do |f|
      f.js { 
        running_instances = KSP.controller.find_running_instances
        if RUBY_PLATFORM =~ /mswin|mingw|cygwin/
          running_instances = running_instances.map{|i| i.executablepath.sub("\\KSP.exe","")}
          tracked_paths = Instance.all.map{|i| i.path.split("/").join("\\")}

          @active_instances = Instance.all.select{|i| running_instances.include?(i.path)}                  
          @instances = running_instances.select{|path| !tracked_paths.include?(path)}
        else
          tracked_paths = Instance.all.map{|i| i.path}
          @active_instances = Instance.all.select{|i| running_instances.include?(i.path)}.map{|i| i.id}
          @instances = running_instances.select{|path| !tracked_paths.include?(path)}
        end
      }
    end  
  end

  def show
    running_instances = KSP.controller.find_running_instances
    instance = Instance.find(params[:id])
    run = true

    if RUBY_PLATFORM =~ /mswin|mingw|cygwin/
      running_instances = running_instances.map{|i| i.executablepath.sub("\\KSP.exe","")}
      run = false if running_instances.include?(instance.path.split("/").join("\\"))    
    else
      run = false if running_instances.include?(instance.path) 
    end

    if run
      KSP.controller.start instance.path        
      notice = "Starting KSP..."
    else
      notice = "This instance is already running</br>click the left side to view its campaigns"
    end
    redirect_to :back, :notice => notice.html_safe
  end

  def edit
  end

  def destroy
    raise params.inspect
  end

end

