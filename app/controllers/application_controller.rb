class ApplicationController < ActionController::Base
  protect_from_forgery
  
  
  after_filter :ensure_delayed_job_running



  private

  def delayed_job_running?
    Dir.open("#{Rails.root}/tmp/pids").to_a.map{|pid| pid.include?('delayed_job')}.any?
  end

  def ensure_delayed_job_running
    return if delayed_job_running?
    start_delayed_job
  end

  def start_delayed_job
    puts "Starting DelayedJob"
    Delayed::Job.destroy_all
    System.start_monitor

    Thread.new do 
      puts "delayed job init"
      Dir.chdir Rails.root
      `ruby script/delayed_job stop`
      `ruby script/delayed_job --queue=monitor start`
    end
  end

end
