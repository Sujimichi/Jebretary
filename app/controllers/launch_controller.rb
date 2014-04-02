class LaunchController < ApplicationController
  #require 'assets/ksp'
  def index
    respond_to do |f|
      f.js {
        running_instances = KSP.controller.find_running_instances
        if RUBY_PLATFORM =~ /mswin|mingw|cygwin/
          begin
            running_instances = running_instances.map{|i| i.executablepath.sub("\\KSP.exe","")}
          rescue
            running_instances = []
          end
          tracked_paths = Instance.all.map{|i| i.path.split("/").join("\\")}

          @active_instances = Instance.all.select{|i| running_instances.include?(i.path.split("/").join("\\"))}.map{|i| i.id}
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
    respond_to do |f|
      running_instances = KSP.controller.find_running_instances
      @instance = Instance.find(params[:id])
      run = false

      if RUBY_PLATFORM =~ /mswin|mingw|cygwin/
        begin
          running_instances = running_instances.map{|i| i.executablepath.sub("\\KSP.exe","")}
        rescue
          running_instance = []
        end
        run = true unless running_instances.include?(@instance.path.split("/").join("\\"))
      else
        run = true unless running_instances.include?(@instance.path)
      end

      if run
        KSP.controller.start @instance.path
        @notice = "Starting KSP..."
      else
        @notice = "This instance is already running</br>click the left side to view its campaigns"
      end

      f.html{
        return_to = request.env["HTTP_REFERER"].nil? ? root_path : :back
        redirect_to return_to, :notice => @notice.html_safe
      }
      f.js{
        @notice.sub!("</br>", ".  ")
      }

    end


  end

  def edit
  end

  def destroy
    respond_to do |f|
      @instance = Instance.find(params[:id])
      shutdown = false

      running_instances = KSP.controller.find_running_instances
      if RUBY_PLATFORM =~ /mswin|mingw|cygwin/
        begin
          shutdown = running_instances.select{|i| i.executablepath.sub("\\KSP.exe","") == @instance.path.split("/").join("\\")}
        rescue
          shutdown = []
        end
      else
        shutdown = running_instances.select{|i| i == @instance.path }
      end

      unless shutdown.empty?
        KSP.controller.terminate shutdown.first
        @notice = "Shutting down KSP :("
      end

      f.html{
        return_to = request.env["HTTP_REFERER"].nil? ? root_path : :back
        redirect_to return_to, :notice => @notice.html_safe
      }
      f.js {}

    end
  end

end

