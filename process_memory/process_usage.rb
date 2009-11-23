class ProcessUsage < Scout::Plugin  
  MEM_CONVERSION = 1024
  
  def build_report
    if @options["command_name"].nil? or @options["command_name"] == ""
      return error("Please specify the name of the process you want to monitor.")
    end
    ps_command   = @options["ps_command"] || "ps auxww"
    ps_regex     = (@options["ps_regex"] || "(?i:\\bCOMMAND\\b)").to_s.
                   gsub("COMMAND") { Regexp.escape(@options["command_name"]) }
    begin
      ps_output    = `#{ps_command}`
    rescue Exception => error
      error("Couldn't use `ps` as expected.", error.message)
    end
    fields       = ps_output.to_a.first.downcase.split
    memory_index = fields.index("rss") or
      return error( "RSS field not found.",
                    "The output from `#{ps_command}` did not include the needed RSS field." )
    highest      =
      ps_output.grep(Regexp.new(ps_regex)).
                map { |com| Float(com.split[memory_index]).abs }.max
    if highest
      report(:memory => (highest/MEM_CONVERSION).to_i)
    else
      error( "Command not found.",
             "No processes found matching #{@options['command_name']}." )
    end
  end
end
