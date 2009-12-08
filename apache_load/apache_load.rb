class ApacheLoad < Scout::Plugin
  needs "net/http", "uri"
	def build_report
    url = URI.parse(option("server_url"))
		req = Net::HTTP::Get.new(url.path + "?" + url.query)
    res = Net::HTTP.start(url.host, url.port) {|http|
      http.request(req)
    }
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