class TomcatMonitor < Scout::Plugin
  
  #  TODO - optional grep filters
  OPTIONS=<<-EOS
    logdir: 
      notes: "absolute path to tomcat localhost_access_log.<YYY-MM-DD>.log"
      default: /opt/jboss/server/default/log
    exclude_filter: 
      notes: "| separated list of grep -v"
      default: "| grep -v HealthCheck | grep -v SessionCheck"
    target_request: 
      notes: narrow response time, rpm calculations to a single transaction 
  EOS

  # TODO - parse grep -v filters, to avoid security issues

  def build_report
    @rpm, @rt,  @req1_rpm, @req1_rt, @req2_rpm, @req2_rt, @req3_rpm, @req3_rt = nil
    @last_line_processed = 0
    @last_date_processed = nil
    @request_comparison = {} # request => {:max => , :count => }

    begin
      requests = parse_logs
      parsed_requests = parse_requests(requests)
      process_requests(parsed_requests)
      report({:rpm => @rpm, :avg_resp_time => @rt, :max_resp_time => @max_rt}) # :comparison => @request_comparison.sort
    rescue StandardError => trouble
      error trouble
    end
  end

  def process_requests(requests)
    @start = @end = nil
    @count = @total_rt = @max_rt = 0
    requests.each do |r|
      begin
        duration = r[0]
        request = r[1],
        @last_date_processed = timestamp = r[2]
        increment_counters(timestamp, duration)
        increment_request_comparison(request, duration)
      rescue StandardError => b
        # swallow Exception and keep going
        p "skipping line: #{line}: #{bang}"
      end
      store_last_date_processed(@last_date_processed)
    end
    @rpm = calc_throughput(@count, @start, @end)
    @rt = calc_request_time(@total_rt, @count)
  end

  def increment_counters(timestamp, duration)
    @start = timestamp unless @start
    @end = timestamp
    @count += 1
    @max_rt = duration if duration > @max_rt
    @total_rt += duration
  end

  def increment_request_comparison(request, duration)
    return @request_comparison[request] = {:max => duration, :count => 1} unless @request_comparison[request]
    max = @request_comparison[request][:max]
    count = @request_comparison[request][:count]
    max = duration if duration > max
    count += 1
    @request_comparison[request] = {:max => max, :count => count}
  end

  def calc_throughput(count, start, zend)
    return 0 if zend - start <= 0
    count / ((zend - start) / 60)
  end

  def calc_request_time(total_rt, count)
    return 0 unless count > 0
   total_rt / count
  end

  #################
  # REQUEST PARSING
  #################

  def parse_requests(requests)
    parsed = []
    requests.each_line do |line|
      begin
        duration, request, log_timestamp = parse_line line
        request = (request.split '?')[0]                     # trim requests down that include attributes
        next unless include_this_request?(request)
        timestamp = time_from_logs log_timestamp
        parsed << [duration, request, timestamp]
      rescue StandardError => bang
        raise "error parsing request, skipping line: #{line}: #{bang}"
      end
    end
    parsed
  end

  # after awk treatment, line should be in format: <timestamp> <duration ms> <http-method-request>
  # i.e. [23/Apr/2011:21:08:35 4 "GET:/servlet/LogoutServlet
  def parse_line(line)
    pos = 0
    duration, http_method, request, timestamp = nil
    line.split.each do |w|
      timestamp = w if pos == 0
      duration = w.to_i if pos == 1
      request = w if pos == 2
      pos += 1
    end
    return duration, request, timestamp
  end

  # convert [18/Apr/2011:22:31:17 to ruby time
  def time_from_logs(log_timestamp)
    stripped = log_timestamp.gsub('[', '').gsub('/', ' ').gsub(':', ' ')
    pos = 0
    year, month, day, hour, min, sec = nil
    stripped.split.each do |w|
      day = w if pos == 0
      month = w if pos == 1
      year = w.to_i if pos == 2
      hour = w if pos == 3
      min = w if pos == 4
      sec = w if pos == 5
      pos += 1
    end
    Time.local(year,month,day,hour,min,sec)
  end

  def timestamp_from_time(time)
    time.strftime("%d/%b/%Y:%H:%M:%S")
  end

  def include_this_request?(request)
    target = target_request
    return true unless target                            # include everything if no target set
    return true if target && request.include?(target)    # request matches target
    return false                                         # request doesn't match target
  end

  def target_request
    option(:target_request) || '' 
  end

  #################
  # LOG PARSING
  #################

  # assumes format:  10.162.73.221 - - [23/Apr/2011:00:00:40 +0000] "GET /client/appraisalWorkshopPrintSignReport.jsp HTTP/1.1" 200 80557
  def parse_logs

    logs = `#{print_file_cmd} #{logfile_absolute_path} #{filters} | awk '{print $4 " "  $6 " "$7":"$8}'`
    raise "unable to parse log" if logs.size <= 0
    logs
  end

  def logfile_absolute_path
    logdir = option(:logdir) || '/opt/jboss/server/default/log'
    today = Date.today
    date_stamp = "#{today.year}-#{"%02d" % today.month}-#{"%02d" % today.day}"
    logfile = "#{logdir}localhost_access_log.#{date_stamp}.log"
    raise "#{logfile} does not exist" unless File.exist?(logfile)
    logfile
  end

  def filters
    option(:exclude_filter) || '| grep -v HealthCheck | grep -v SessionCheck'
  end

  # use cat to parse entire log file, tail -n to skip lines
  def print_file_cmd
    last_date_processed = remember_last_date_processed
    p 'parsing entire logfile' unless last_date_processed && last_date_processed.is_a?(Time)
    return 'cat ' unless last_date_processed && last_date_processed.is_a?(Time)
    search_for = timestamp_from_time last_date_processed
    line = `grep --line-number #{search_for} #{logfile_absolute_path}`
    line_number = (line.split ':')[0]       # parsing line # from front of log:  36164:10.162.73.221 - - [23/Apr/2011:15:51:46 +0000
    p "skipping to line #{line_number}"
    "tail -n+#{line_number}"
  end

  def store_last_date_processed(date)
#    remember :last_date_processed => nil
    remember :last_date_processed => date
  end

  def remember_last_date_processed
    memory(:last_date_processed)
  end

end
