class PassengerStatus < Scout::Plugin
  def build_report
    cmd  = option(:passenger_status_command) || "passenger-status"
    data = `#{cmd} 2>&1`
    if $?.success?
      stats = parse_data(data)
      report(stats)
    else
      error "Could not get data from command", "Error:  #{data}"
    end
  end

  private

  def parse_data(data)
    stats = {}
    
    data.each_line do |line|
      #line = line.gsub(/\e\[\d+m/,'')
      if line =~ /^max\s+=\s(\d+)/
        stats["max"] = $1
      elsif line =~ /^count\s+=\s(\d+)/
        stats["current"] = $1
      elsif line =~ /^active\s+=\s(\d+)/
        stats["active"] = $1
      elsif line =~ /^inactive\s+=\s(\d+)/
        stats["inactive"] = $1
      elsif line =~ /^Waiting on global queue: (\d+)/
        stats["gq_wait"] = $1

      end
    end

    stats
  end

end
