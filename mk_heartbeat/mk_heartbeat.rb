class CheckMkHeartbeat < Scout::Plugin
  # An embedded YAML doc describing the options this plugin takes
  OPTIONS=<<-EOS
    path:
      name: Path
      notes: "Absolute path to the mk-heartbeat log file"
      default: "/fpo/shared/log/mk-heartbeat.log"
    threshold:
      name: Threshold
      notes: "The number of seconds the slave can be behind the master before and alert is triggered"
      default: 60
  EOS

  # Every plugin needs a build_report method
  def build_report
    begin
      threshold = option(:threshold).to_f
      path = option(:path)

      if path.nil? || path.empty?
        return error("The path to the mk-heartbeat log file wasn't provided.", "Please provide the full path to the log file.")
      end

      seconds = 0.0
      line = ""

      File.open(path, "r") do |file|
        line = file.readline
        match = line.scan(/^\s*(\d*\.?\d*)s/i).first
        if match.nil?
          output = "Path: #{path}, Threshold: #{threshold} seconds, Contents: #{line}, Seconds: #{seconds}"
          alert("File #{path} does not seem to contain any data.", output)
        else
          seconds = match.first.to_f
        end
      end

      output = "Path: #{path}, Threshold: #{threshold} seconds, Contents: #{line}, Seconds: #{seconds}"

      report(:seconds => seconds, :threshold => threshold)
      if seconds > threshold
        alert("MK-Heartbeat is #{seconds} seconds old, which is over the threshold of #{threshold} seconds", output)
      end
      return seconds
    rescue Exception => e
      error("Error running Check MkHeartbeat plugin\n#{e}")
      return -1
    end
  end
end

