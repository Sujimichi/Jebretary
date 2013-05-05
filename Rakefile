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
