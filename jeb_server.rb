
trap("SIGINT") { throw :ctrl_c }

catch :ctrl_c do
  begin
    while true
      thread = Thread.new{
        puts "foo"
        system "bundle exec script/rails s"
        puts "bar"
      }
      sleep(60)
      thread.kill
    end
  rescue Exception
    puts "Not printed"
  end
end

def thing
  while true

    thread = Thread.new{
      system "bundle exec script/rails s -e production"
    }
    sleep 20
    thread.kill
    sleep 2
    GC.start


  end
end
