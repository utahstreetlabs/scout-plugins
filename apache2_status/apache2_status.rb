# Apache2 Status by Hampton Catlin
#
# Free Use Under the MIT License
#
# Please note, your server must respond to "apache2ctl status"
#
class Apache2Status < Scout::Plugin

  def build_report
    report(:requests_being_processed => requests_being_processed)
    report(:apache_reserved_memory_size => apache_reserved_memory_size)
  end
  
  # Calculate the total reserved memory size from a ps aux with a couple greps
  def apache_reserved_memory_size
    # Fetch the process list and split it into an array
    process_list = (`ps aux | grep apache2 | grep -v grep | grep -v ruby`).split("\n")
    
    # Aggregate with this variable
    memory_size = 0
    
    # Iterate over the process list and sum up the memory values
    process_list.each do |line|
      # Split the data into columns
      columns = line.split(" ")
      memory_size += columns[4].to_i
    end
    
    # Calculate how many MB that is
    mb = ((memory_size / 1024.0) / 1024)
    
    # Display with MB on the end
    mb.to_s + " MB"
  end
  
  # Run the calcuations for requests being processed by apache2
  def requests_being_processed

    total_requests_being_processed = 0

    # How many samples should we do?
    sample_size = option('sample_size').to_i

    sample_size.times do
      # Sum up the total number of requests by calling the fetch method
      total_requests_being_processed += fetch_requests_being_processed
      
      # Pause for a moment to make sure the sample is good
      sleep(option('sample_sleep').to_f)
    end

    # Return the average number of requests
    average_requests_being_processed = (total_requests_being_processed / sample_size)
  end

  # At this particular moment, how many requests are being processed?
  def fetch_requests_being_processed
    # Must have mod_status installed
    results = `apache2ctl status 2>/dev/null`
    requests_being_processed = results.match(/([0-9]*) requests currently being processed/)[1].to_i
  end
end
