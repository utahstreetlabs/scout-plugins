class ProcessUsage < Scout::Plugin  
  MEM_CONVERSION = 1024
  
  def build_report
    if option(:command_name).nil? or option(:command_name) == ""
      return error("Please specify the name of the process you want to monitor.")
    end
    ps_command   = option(:ps_command) || "ps auxww"
    ps_regex     = (option(:ps_regex) || "(?i:\\bCOMMAND\\b)").to_s.gsub("COMMAND") { Regexp.escape(option(:command_name)) }
    begin
      ps_output    = `#{ps_command}`
    rescue Exception => error
      error("Couldn't use `ps` as expected.", error.message)
    end
    ps_lines     = ps_output.split(/\n/)
    fields       = ps_lines.first.downcase.split
    memory_index = fields.index("rss") or
      return error( "RSS field not found.",
                    "The output from `#{ps_command}` did not include the needed RSS field." )

    # narrow the ps lines to just those mentioning the process we're interested in
    process_lines = ps_lines.grep(Regexp.new(ps_regex))

    if process_lines.any?
      rss_values    = process_lines.map { |com| Float(com.split[memory_index]).abs }
      highest       = rss_values.max
      total         = rss_values.inject(0){|s,value| s=s + value }

      report(:memory        => (highest/MEM_CONVERSION).to_i,
             :total_rss  => (total/MEM_CONVERSION).to_i,
             :num_processes => process_lines.size)
    else
      error( "Command not found.",
             "No processes found matching #{option(:command_name)}." )
    end
  end
end
