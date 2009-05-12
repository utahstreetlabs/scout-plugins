class Apache2Status < Scout::Plugin

  def build_report
    report(:requests_being_processed => requests_being_processed)
    report(:apache_reserved_memory_size => apache_reserved_memory_size)
  end
  
  def apache_reserved_memory_size
    process_list = `ps aux | grep apache2 | grep -v grep | grep -v ruby`.split("\n")
    
    memory_size = 0
    process_list.collect! do |line|
      memory_size += line.split(" ")[4].to_i
    end
    
    memory_size.to_s + " bytes"
  end
  
  def requests_being_processed
	  
    total_requests_being_processed = 0
    sample_size = option('sample_size').to_i

    sample_size.times do
     total_requests_being_processed += fetch_requests_being_processed
     sleep(option('sample_sleep').to_f)
    end
    
    average_requests_being_processed = (total_requests_being_processed / sample_size)
  end
  
  def fetch_requests_being_processed
    results = `apache2ctl status`
    requests_being_processed = results.match(/([0-9]*) requests currently being processed/)[1].to_i
  end
end
