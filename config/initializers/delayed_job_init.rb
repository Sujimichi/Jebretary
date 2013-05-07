def start_delayed_job
  `ruby script/delayed_job --queue=monitor start`
end

def stop_delayed_job
  `ruby script/delayed_job stop`
end


#if !File.exist?(DELAYED_JOB_PID_PATH) && process_is_dead?
  Delayed::Job.destroy_all
  System.start_monitor

  Thread.new do 
    puts "delayed job init"
    stop_delayed_job
    start_delayed_job
  end
#end
