$VERBOSE=false
class ApacheLoad < Scout::Plugin
  needs "net/http", "uri"
  
  OPTIONS=<<-EOS
    server_url:
      name: Server Status URL
      notes: Specify URL of the server-status page to check. Scout requires the machine-readable format of the status page (just add '?auto' to the server-status page URL).
      default: "http://localhost/server-status?auto"
  EOS
  
	def build_report
    url = URI.parse(option("server_url"))
		req = Net::HTTP::Get.new(url.path + "?" + url.query.to_s)
		http = Net::HTTP.new(url.host, url.port)
		http.use_ssl = url.is_a?(URI::HTTPS)
    res = http.start() {|h|
      h.request(req)
    }
    
    unless [Net::HTTPOK,Net::HTTPFound].include?(res.class) 
      return error("Unable to access status page","The server-status page (#{url}) was not accessible:\n\n#{res.class}\n\nPlease ensure the server-status page is configured in your Apache settings.")
    end
    
		values = {}
		res.body.split("\n").each do |item|
			k, v = item.split(": ")
			values[k] = v
		end
		total_accesses = values['Total Accesses'].to_i
		if (memory(:last_run_total_accesses) && memory(:last_run_time))
			accesses_since_last_run = total_accesses - memory(:last_run_total_accesses)
			seconds_since_last_run = Time.now - memory(:last_run_time)
		else
			accesses_since_last_run = total_accesses
			seconds_since_last_run = values['Uptime'].to_i
		end
		
		current_accesses_per_second = accesses_since_last_run / seconds_since_last_run
		
		report(:current_load => current_accesses_per_second)
    remember(:last_run_time => Time.now)
    remember(:last_run_total_accesses => total_accesses)
  end
end