class Apache2Status < Scout::Plugin

  def build_report
    results = `apache2ctl status`
    
    requests_being_processed = results.match(/([0-9]*) requests currently being processed/)[1].to_i
    report(:requests_being_processed => requests_being_processed)
    
    process_list = `ps aux | grep apache2 | grep -v grep | grep -v ruby`.split("\n")
    
    
    memory_size = 0
    process_list.collect! do |line|
      memory_size += line.split(" ")[4].to_i
    end
    
    report(:apache_reserved_memory_size => memory_size.to_s + " bytes")
  end
end