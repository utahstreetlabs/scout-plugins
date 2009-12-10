class ProcessUsage < Scout::Plugin  
  MEM_CONVERSION = 1024
  
  def build_report
    if option(:command_name).nil? or option(:command_name) == ""
      return error("Please specify the name of the process you want to monitor.")
    end
    ps_command   = option(:ps_command) || "ps auxww"
    ps_regex     = (option(:ps_regex) || "(?i:\\bCOMMAND\\b)").to_s.gsub("COMMAND") { Regexp.escape(option(:command_name)) }

    ps_output = `#{ps_command}`
    unless $?.success?
      return error("Couldn't use `ps` as expected.", error.message)
    end

    ps_lines = ps_output.split(/\n/)
    fields   = ps_lines.shift.downcase.split
    unless (memory_index = fields.index("rss")) && (pid_index = fields.index('pid'))
      return error( "RSS or PID field not found.",
                    "The output from `#{ps_command}` did not include the needed RSS and PID fields." )
    end

    # narrow the ps lines to just those mentioning the process we're interested in
    process_lines = ps_lines.grep(Regexp.new(ps_regex))

    if process_lines.any?
      rss_values = process_lines.map { |com| Float(com.split[memory_index]).abs }
      pids       = process_lines.map { |com| Integer(com.split[pid_index]) }
      highest    = rss_values.max
      total      = rss_values.inject(0){|s,value| s + value }

      if remembered_pids = memory(:pids)
        report(:restarts => (pids - remembered_pids).length)
      end

      report(:memory        => (highest/MEM_CONVERSION).to_i,
             :total_rss     => (total/MEM_CONVERSION).to_i,
             :num_processes => process_lines.size)

      remember(:pids => pids)
    else
      error( "Command not found.",
             "No processes found matching #{option(:command_name)}." )
    end
  rescue Exception => e
    error("Error when executing: #{e.class}", e.message)
  end
end
