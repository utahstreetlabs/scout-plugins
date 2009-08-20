require "time"

class RailsRequests < Scout::Plugin
  TEST_USAGE = "#{File.basename($0)} log LOG max_request_length MAX_REQUEST_LENGTH last_run LAST_RUN"
  
  needs "elif"
  
  def build_report
    log_path = option(:log)
    unless log_path and not log_path.empty?
      return error("A path to the Rails log file wasn't provided.")
    end

    report_data        = { :slow_request_count     => 0,
                           :request_count          => 0,
                           :average_request_length => nil }
    last_completed     = nil
    slow_requests      = ''
    total_request_time = 0.0
    last_run           = memory(:last_run) || Time.now
    
    Elif.foreach(log_path) do |line|
      if line =~ /\ACompleted in (\d+)ms .+ \[(\S+)\]\Z/        # newer Rails
        last_completed = [$1.to_i / 1000.0, $2]
      elsif line =~ /\ACompleted in (\d+\.\d+) .+ \[(\S+)\]\Z/  # older Rails
        last_completed = [$1.to_f, $2]
      elsif last_completed and
            line =~ /\AProcessing .+ at (\d+-\d+-\d+ \d+:\d+:\d+)\)/
        time_of_request = Time.parse($1)
        if time_of_request < last_run
          break
        else
          # logger.info 'increment'
          report_data[:request_count] += 1
          total_request_time          += last_completed.first.to_f
          if option(:max_request_length).to_f > 0 and
             last_completed.first.to_f > option(:max_request_length).to_f
            report_data[:slow_request_count] += 1
            slow_requests                    += "#{last_completed.last}\n"
            slow_requests                    += "Time: #{last_completed.first} sec\n\n"
          end
        end # request should be analyzed
      end
    end
    
    # Create a single alert that holds all of the requests that exceeded the +max_request_length+.
    if (count = report_data[:slow_request_count]) > 0
      alert( "Maximum Time(#{option(:max_request_length)} sec) exceeded on #{count} request#{'s' if count != 1}",
             slow_requests )
    end
    # Calculate the average request time if there are any requests
    if report_data[:request_count] > 0
      avg                                  = total_request_time /
                                             report_data[:request_count]
      report_data[:average_request_length] = sprintf("%.2f", avg)
    end
    remember(:last_run,Time.now)
    report(report_data)
  end
end
