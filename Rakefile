#!/usr/bin/env rake
# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

require File.expand_path('../config/application', __FILE__)


Jebretary::Application.load_tasks

task :reset do
  `rake db:drop:all`
  `rake db:create:all`
  `rake db:migrate`
  `rake db:test:prepare`
end


task :monitor => :environment do 

  print "Running Monitor..."
  System.run_monitor
  puts "done"

end


task :clean_temps do 
  if (RUBY_PLATFORM =~ /mswin|mingw|cygwin/) && ENV["OCRA_EXECUTABLE"]
    cur_dir = Dir.getwd
    puts "Current temp dir: #{cur_dir}"
    Dir.chdir File.join([Dir.getwd, "..", ".."])

    past_temp_dirs = Dir.entries(Dir.getwd).select{|dir| dir.match(/ocr[A-Z0-9]{4}.tmp/) && !cur_dir.include?(dir) }
    unless past_temp_dirs.empty?
      puts "cleaning up temp dir from previous runs"
      past_temp_dirs.each{|dir| 
        puts "removing temp dir #{File.expand_path(dir)}"
        FileUtils.rm_rf(dir) 
      }
    end
  end

end


task :ocra_prepare do 

  puts "This will reset the production database db/production.sqlite3"
  print "\nYou have 5 seconds to hit ctrl-C before I continue"
  n = 5
  n.times {
    sleep 1
    print "."
  }
  puts "proceeding"

  print "\n\rDopping DB's and rebuilding"
  Rake::Task["db:drop:all"].execute
  print "."
  Rake::Task["db:create:all"].execute
  print "."
  `bundle exec rake db:migrate`
  print "."
  Rake::Task["db:test:prepare"].execute
  print "."
  `bundle exec rake db:migrate RAILS_ENV=production`
  print "."
  puts "done"

  puts "\nprecompiling assets"
  Rake::Task["assets:precompile"].execute


  print "\nRemoving log files"
  Dir.entries(File.join([Rails.root, "log"])).select{|f| f.include?('.log')}.each{|log|
    File.delete( File.join([Rails.root, "log", log]) )
    print "."
  }
  puts " done"
  
  print "\nRemoving any flag images from public"
  Dir.entries(File.join([Rails.root, "public"])).select{|f| f.include?('flag_for_campaign_')}.each{|flag|
    File.delete( File.join([Rails.root, "public", flag]) )
    print "."
  }
  puts " done"



  puts "\n\nReady for ISS installer build."   #(#{File.join([Rails.root, ".."])})"
  puts "make sure the files in jebretary_build are uptodate"
  puts "run build_runnner.bat and build_launcher.bat if the entry points have changed"
  puts "run build_app.bat to build the app"

end


