# Created by Benjamin Stein, Mobile Commons
#
# We have a number of daemons that bounce on deploy, including resque
# workers and custom scripts. Sometimes we've seen processes fail to
# restart (maybe the process was busy and didn't trap the SIGHUP?). The
# result is stale processes whose code is out of sync with the database.
# 
# So this is a script that will check the timestamp of our current Rails
# deploy and alert us if the start time of any daemons are older than
# that.

$VERBOSE=false
require 'time'
class StaleDaemonMonitor < Scout::Plugin  

  START_TIME_HEADER = 'started'
  
  OPTIONS=<<-EOS
  command_name:
    name: Command Name
  rails_root:
    name: Rails Root Path
    notes: "Full path to the root directory of the Rails application"
  ps_command:
    name: "PS Command"
    default: "ps auxww"
    attributes: advanced
  ps_regex:
    name: "PS Regular Expression"
    default "(?i:\\bCOMMAND\\b)"
    attributes: advanced
  EOS

  def build_report
    if option(:command_name).nil?
      return error("Please specify the name of the process you want to monitor.")
    end

    if option(:rails_root).nil? || !File.readable?(option(:rails_root))
      return error("Please specify readable Rails root.")
    end
    current_deployment_time = File.ctime(option(:rails_root))
    
    ps_command   = option(:ps_command) || "ps auxww"
    ps_regex     = (option(:ps_regex) || "(?i:\\bCOMMAND\\b)").to_s.gsub("COMMAND") { Regexp.escape(option(:command_name)) }

    ps_output = `#{ps_command}`
    unless $?.success?
      return error("Couldn't use `ps` as expected.", error.message)
    end

    ps_lines         = ps_output.split(/\n/)
    fields           = ps_lines.shift.downcase.split
    start_time_index = fields.index(START_TIME_HEADER)
    if start_time_index.nil?
      return error("The output from `#{ps_command}` did not include the #{START_TIME_HEADER} fields." )
    end

    process_lines = ps_lines.grep(Regexp.new(ps_regex))
    stale_processes = process_lines.select do |line| 
      process_started_at = Time.parse(line.split[start_time_index])
      process_started_at < current_deployment_time
    end

    if stale_processes.any?
      alert("Found Stale Process", stale_processes.join("\n"))
    end
    
  rescue Exception => e
    error("Error when executing: #{e.class}", e.message)
  end

end
