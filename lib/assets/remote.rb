class Remote


  def self.version args = {:pre => false}
    releases = Remote.releases args
    unless releases.empty?
      current_release = releases.first
      current_release["tag_name"]
    else
      nil
    end
  end


  def self.releases args = {:pre => false}
    response = Remote.get_data("https://api.github.com/repos/Sujimichi/Jebretary/releases")

    begin
      releases = JSON.parse(response)
      releases.select{|release| not release["prerelease"]} unless args[:pre]
    rescue
      return []
    end
  end


  def self.change_log args = {}
    begin
      response = Remote.get_data("https://raw.githubusercontent.com/Sujimichi/Jebretary/master/README.rdoc")
      if response
        history = response.split("==Version History").last
        history = history.split("\n==").first.split("==").map{|l| l.strip}.select{|l| !l.to_s.empty?}
        log = history.map{|hist| 
          details = hist.split("\n").reverse
          [details.pop, details.reverse.join.strip]
        }
      end
    rescue
      log = []
    end

    if args[:from]
      versions = log.map{|l| l.first}
      index = versions.index(args[:from])
      index = 5 if index.nil?

      log = log[0..index]
    end
    log
  end

  def self.get_data url
    require 'net/http'
    begin
      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      response = http.get(uri.request_uri)
      response.body
    rescue
      return nil
    end
  end
end
