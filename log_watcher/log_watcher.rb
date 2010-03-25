class LogWatcher < Scout::Plugin
  
  OPTIONS = <<-EOS
  log_path:
    name: Log path
    notes: Full path to the the log file
  term:
    default: "[Ee]rror"
    name: Term
    notes: Returns the number of matches for this term. Use Linux Regex formatting.
  EOS
  
  def init
    @log_file_path = option("log_path").to_s.strip
    if @log_file_path.empty?
      return error( "Please provide a path to the log file." )
    end
    
    unless File.exist?(@log_file_path)
      return error("Could not find the log file", "The log file could not be found at: #{@log_file_path}. Please ensure the full path is correct.")
    end

    @term = option("term").to_s.strip
    if @term.empty?
      return error( "The term cannot be empty" )
    end
    nil
  end
  
  def build_report
    return if init()
    
    last_bytes = memory(:last_bytes) || 0
    current_length = `wc -c #{@log_file_path}`.split(' ')[0].to_i
    count = 0

    # don't run it the first time
    if (last_bytes > 0 )
      read_length = current_length - last_bytes
      # Check to see if this file was rotated. This occurs when the +current_length+ is less than 
      # the +last_run+. Don't return a count if this occured.
      if read_length >= 0
        count = `tail -c #{read_length} #{@log_file_path} | grep "#{@term}" -c`.strip.to_f
        # convert to a rate / min
        count = count / ((Time.now - @last_run)/60)
      else
        count = nil
      end
    end
    report(:occurances => count) if count
    remember(:last_bytes, current_length)
  end
end