class LaunchController < ApplicationController
  require 'assets/ksp'
  def index
    respond_to do |f|
      f.js { 
        @instances = KSP::Windows.find_running_instances.map{|i| i.executablepath}
        @instances = @instances.map{|path| path.sub("\\KSP.exe","")}
        tracked_paths = Instance.all.map{|i| i.path.split("/").join("\\")}
        @instances = @instances.select{|path| !tracked_paths.include?(path)}
      }
    end  
  end

  def show
    instance = Instance.find(params[:id])
    KSP::Windows.start instance.path
    redirect_to :back
  end

  def edit
  end

  def destroy
  end

end

