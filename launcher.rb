#!/usr/bin/env ruby
require 'fileutils'

begin
  FileUtils.rm_rf File.join(["src", "tmp"]) #clean tmp dir
  @cleanup = :ok
rescue
  @cleanup = :failed
end

if @cleanup.eql?(:ok)
  system "start jeb_watch.exe"
  system "start rails.exe"
else
  puts "Appears we have a problem launching"
  puts "Unable to remove tmp files from previous run, possibly another instance is currently still active?"
  puts "Check to see if any processes called 'ruby' are running in your task manager and terminate them."
  puts "Then attempt to manually remove the tmp dir 'src/tmp' inside where Jebretary is installed."
  puts "Then I should stop fussing and just run"
  
end
