class Remote


 def self.version v_type = :stable
    begin
      response = Remote.get_data("https://raw.githubusercontent.com/Sujimichi/Jebretary/master/lib/assets/version.rb")
      
      if response
        data = response.split("\n")
        version_line = data.select{|d| 
          d.include?({:edge => "VERSION", :stable => "RELEASE_VERSION"}[v_type])
        }.first

        raise "could not read version line" if version_line.nil?
        remote_version = version_line.split("\"").last

        if v_type == :stable
          release_url_line = data.select{|d| 
            d.include?("RELEASE_URL")
          }.first
          raise "could not read release url" if release_url_line.nil?
          release_url = release_url_line.split("\"").last
        end
      end
    rescue
      remote_version = "unknown"
    end
    data = {:version => remote_version}
    data[:url] = release_url if release_url
    data
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
    begin
      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      response = http.get(uri.request_uri)
      data = response.body
    rescue
      data = nil
    end
    data
  end
end
