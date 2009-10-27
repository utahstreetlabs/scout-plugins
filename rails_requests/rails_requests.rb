require "time"
require "stringio"

class RailsRequests < Scout::Plugin
  ONE_DAY    = 60 * 60 * 24
  TEST_USAGE = "#{File.basename($0)} log LOG max_request_length MAX_REQUEST_LENGTH last_run LAST_RUN"
  
  needs "elif"
  needs "request_log_analyzer"
  
  def build_report
    patch_elif

    log_path = option(:log)
    unless log_path and not log_path.empty?
      @file_found = false
      return error("A path to the Rails log file wasn't provided.","Please provide the full path to the Rails log file to analyze (ie - /var/www/apps/APP_NAME/log/production.log)")
    end
    max_length = option(:max_request_length).to_f

    # process the ignored_actions option -- this is a regex provided by users; matching URIs don't get counted as slow
    ignored_actions=nil
    if option(:ignored_actions) && option(:ignored_actions).strip != ''
      begin
        ignored_actions = Regexp.new(option(:ignored_actions))
        puts ignored_actions.inspect
      rescue
        error("Argument error","Could not understand the regular expression for excluding slow actions: #{option(:ignored_actions)}. #{$!.message}")
      end
    end

    report_data        = { :slow_request_rate     => 0,
                           :request_rate          => 0,
                           :average_request_length => nil }
    slow_request_count = 0
    request_count      = 0
    last_completed     = nil
    slow_requests      = ''
    total_request_time = 0.0
    last_run           = memory(:last_request_time) || Time.now
    # needed to ensure that the analyzer doesn't run if the log file isn't found.
    @file_found        = true 

    Elif.foreach(log_path) do |line|
      if line =~ /\A(Completed in (\d+)ms .+) \[(\S+)\]\Z/        # newer Rails
        last_completed = [$2.to_i / 1000.0, $1, $3]
      elsif line =~ /\A(Completed in (\d+\.\d+) .+) \[(\S+)\]\Z/  # older Rails
        last_completed = [$2.to_f, $1, $3]
      elsif last_completed and
            line =~ /\AProcessing .+ at (\d+-\d+-\d+ \d+:\d+:\d+)\)/
        time_of_request = Time.parse($1)
        if time_of_request < last_run
          break
        else
          request_count += 1
          total_request_time          += last_completed.first.to_f
          if max_length > 0 and last_completed.first > max_length
            # only test for ignored_actions if we actually have an ignored_actions regex
            if ignored_actions.nil? || (ignored_actions.is_a?(Regexp) && !ignored_actions.match(last_completed.last))
              slow_request_count += 1
              slow_requests                    += "#{last_completed.last}\n"
              slow_requests                    += "#{last_completed[1]}\n\n"
            end
          end
        end # request should be analyzed
      end
    end
    
    # Create a single alert that holds all of the requests that exceeded the +max_request_length+.
    if (count = slow_request_count) > 0
      alert( "Maximum Time(#{option(:max_request_length)} sec) exceeded on #{count} request#{'s' if count != 1}",
             slow_requests )
    end
    # Calculate the average request time and request rate if there are any requests
    if request_count > 0
      # calculate the time btw runs in minutes
      interval = (Time.now-last_run)

      interval < 1 ? inteval = 1 : nil # if the interval is less than 1 second (may happen on initial run) set to 1 second
      interval = interval/60 # convert to minutes
      interval = interval.to_f
      # determine the rate of requests and slow requests in requests/min
      request_rate                         = request_count /
                                             interval
      report_data[:request_rate]           = sprintf("%.2f", request_rate)
      
      slow_request_rate                    = slow_request_count /
                                             interval
      report_data[:slow_request_rate]      = sprintf("%.2f", slow_request_rate)
      
      # determine the average request length
      avg                                  = total_request_time /
                                             request_count
      report_data[:average_request_length] = sprintf("%.2f", avg)
    end
    remember(:last_request_time, Time.now)
    report(report_data)
  rescue Errno::ENOENT => error
    @file_found = false
    error("Unable to find the Rails log file", "Could not find a Rails log file at: #{option(:log)}. Please ensure the path is correct.")
  rescue Exception => error
    error("#{error.class}:  #{error.message}", error.backtrace.join("\n"))
  ensure
    # only run the analyzer if the log file is provided
    # this make take a couple of minutes on large log files.
    if @file_found and option(:log) and not option(:log).empty?
      generate_log_analysis(log_path)
    end
  end
  
  private
  
  def silence
    old_verbose, $VERBOSE, $stdout = $VERBOSE, nil, StringIO.new
    yield
  ensure
    $VERBOSE, $stdout = old_verbose, STDOUT
  end
  
  def generate_log_analysis(log_path)
    # decide if it's time to run the analysis yet today
    if option(:rla_run_time) =~ /\A\s*(0?\d|1\d|2[0-3]):(0?\d|[1-4]\d|5[0-9])\s*\z/
      run_hour    = $1.to_i
      run_minutes = $2.to_i
    else
      run_hour    = 23
      run_minutes = 45
    end
    now = Time.now
    if last_summary = memory(:last_summary_time)
      if now.hour > run_hour       or
        ( now.hour == run_hour     and
          now.min  >= run_minutes ) and
         %w[year mon day].any? { |t| last_summary.send(t) != now.send(t) }
        remember(:last_summary_time, now)
      else
        remember(:last_summary_time, last_summary)
        return
      end
    else
      last_summary = now - ONE_DAY
      remember(:last_summary_time, last_summary)
    end
    # make sure we get a full run
    if now - last_summary < 60 * 60 * 22
      last_summary = now - ONE_DAY
    end
    
    self.class.class_eval(RLA_EXTS)
    
    analysis = analyze(last_summary, now, log_path)
    
    summary( :command => "request-log-analyzer --after '"                   +
                         last_summary.strftime('%Y-%m-%d %H:%M:%S')         +
                         "' --before '" + now.strftime('%Y-%m-%d %H:%M:%S') +
                         "' '#{log_path}'",
             :output  => analysis )
  rescue Exception => error
    error("#{error.class}:  #{error.message}", error.backtrace.join("\n"))
  end
  
  def analyze(last_summary, stop_time, log_path)
    log_file = read_backwards_to_timestamp(log_path, last_summary)
    if RequestLogAnalyzer::VERSION <= "1.3.7"
      analyzer_with_older_rla(last_summary, stop_time, log_file)
    else
      analyzer_with_newer_rla(last_summary, stop_time, log_file)
    end
  end
  
  def analyzer_with_older_rla(last_summary, stop_time, log_file)
    summary  = StringIO.new
    output   = EmbeddedHTML.new(summary)
    format   = RequestLogAnalyzer::FileFormat.load(:rails)
    options  = {:source_files => log_file, :output => output}
    source   = RequestLogAnalyzer::Source::LogParser.new(format, options)
    control  = RequestLogAnalyzer::Controller.new(source, options)
    control.add_filter(:timespan, :after  => last_summary)
    control.add_filter(:timespan, :before => stop_time)
    control.add_aggregator(:summarizer)
    source.progress = nil
    format.setup_environment(control)
    silence do
      control.run!
    end
    summary.string.strip
  end
  
  def analyzer_with_newer_rla(last_summary, stop_time, log_file)
    summary = StringIO.new
    RequestLogAnalyzer::Controller.build(
      :output       => EmbeddedHTML,
      :file         => summary,
      :after        => last_summary, 
      :before       => stop_time,
      :source_files => log_file
    ).run!
    summary.string.strip
  end
  
  def patch_elif
    if Elif::VERSION < "0.2.0"
      Elif.send(:define_method, :pos) do
        @current_pos +
        @line_buffer.inject(0) { |bytes, line| bytes + line.size }
      end
    end
  end
  
  def read_backwards_to_timestamp(path, timestamp)
    start = nil
    Elif.open(path) do |elif|
      elif.each do |line|
        if line =~ /\AProcessing .+ at (\d+-\d+-\d+ \d+:\d+:\d+)\)/
          time_of_request = Time.parse($1)
          if time_of_request < timestamp
            break
          else
            start = elif.pos
          end
        end
      end
    end

    file = open(path)
    file.seek(start) if start
    file
  end
  
  RLA_EXTS = <<-'END_RUBY'
  class EmbeddedHTML < RequestLogAnalyzer::Output::Base
    def print(str)
      @io << str
    end
    alias_method :<<, :print
  
    def puts(str = "")
      @io << "#{str}<br/>\n"
    end
  
    def title(title)
      @io.puts(tag(:h2, title))
    end
  
    def line(*font)  
      @io.puts(tag(:hr))
    end
  
    def link(text, url = nil)
      url = text if url.nil?
      tag(:a, text, :href => url)
    end
  
    def table(*columns, &block)
      rows = Array.new
      yield(rows)
  
      @io << tag(:table, :cellspacing => 0) do |content|
        if table_has_header?(columns)
          content << tag(:tr) do
            columns.map { |col| tag(:th, col[:title]) }.join("\n")
          end
        end
  
        odd = false
        rows.each do |row|
          odd = !odd
          content << tag(:tr) do
            if odd
              row.map { |cell| tag(:td, cell, :class => "alt") }.join("\n") 
            else
              row.map { |cell| tag(:td, cell) }.join("\n") 
            end
          end
        end
      end
    end
  
    def header
    end
  
    def footer
      @io << tag(:hr) << tag(:p, "Powered by request-log-analyzer v#{RequestLogAnalyzer::VERSION}")
    end
  
    private
  
    def tag(tag, content = nil, attributes = nil)
      if block_given?
        attributes = content.nil? ? "" : " " + content.map { |(key, value)| "#{key}=\"#{value}\"" }.join(" ")
        content_string = ""
        content = yield(content_string)
        content = content_string unless content_string.empty? 
        "<#{tag}#{attributes}>#{content}</#{tag}>"
      else
        attributes = attributes.nil? ? "" : " " + attributes.map { |(key, value)| "#{key}=\"#{value}\"" }.join(" ")
        if content.nil?
          "<#{tag}#{attributes} />"
        else
          if content.class == Float
            "<#{tag}#{attributes}><div class='color_bar' style=\"width:#{(content*200).floor}px;\"/></#{tag}>"
          else
            "<#{tag}#{attributes}>#{content}</#{tag}>"
          end
        end
      end
    end  
  end
  END_RUBY
end
