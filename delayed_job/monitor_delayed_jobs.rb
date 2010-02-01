
class MonitorDelayedJobs < Scout::Plugin
  ONE_DAY    = 60 * 60 * 24
  
  OPTIONS=<<-EOS
  path_to_app:
    name: Full Path to the Rails Application
  rails_env:
    name: Rails environment that should be used
    default: production
  log:
    name: Full Path to Delayed Job Log File
    notes: "The full path to the Delayed Job log file you wish to analyze (ex: /var/www/apps/APP_NAME/current/log/delayed_job.log)."
  rla_run_time:
    name: Request Log Analyzer Run Time (HH:MM)
    notes: It's best to schedule these summaries about fifteen minutes before any logrotate cron job you have set would kick in.
    default: '23:45'
  EOS
  
  needs 'activerecord', 'yaml', 'elif', 'request_log_analyzer'
  
  require 'activerecord'
  
  # Format used by RLA to parse the log file.
  DELAYED_JOB_RLA_FORMAT = 'delayed_job'

  class DelayedJob < ActiveRecord::Base; end
  
  def build_report
    
    app_path = option(:path_to_app)
    
    # Ensure path to db config provided
    if !app_path or app_path.empty?
      return error("The path to the Rails Application wasn't provided.","Please provide the full path to the Rails Application (ie - /var/www/apps/APP_NAME/current)")
    end
    
    db_config = YAML::load(File.open(app_path + '/config/database.yml'))
    ActiveRecord::Base.establish_connection(db_config[option(:rails_env)])
    
    log_path = option(:log)
    
    report_hash = Hash.new
    
    # ALl jobs
    report_hash[:total]     = DelayedJob.count
    # Jobs that are currently being run by workers
    report_hash[:running]   = DelayedJob.count(:conditions => 'locked_at IS NOT NULL')
    # Jobs that are ready to run but haven't ever been run
    report_hash[:waiting]   = DelayedJob.count(:conditions => [ 'run_at <= ? AND locked_at IS NULL AND attempts = 0', Time.now.utc ])
    # Jobs that haven't ever been run but are not set to run until later
    report_hash[:scheduled] = DelayedJob.count(:conditions => [ 'run_at > ? AND locked_at IS NULL AND attempts = 0', Time.now.utc ])
    # Jobs that aren't running that have failed at least once
    report_hash[:failing]   = DelayedJob.count(:conditions => 'attempts > 0 AND failed_at IS NULL AND locked_at IS NULL')
    # Jobs that have permanently failed
    report_hash[:failed]    = DelayedJob.count(:conditions => 'failed_at IS NOT NULL')
    
    report(report_hash)
    
    # The oldest job that hasn't yet been run, in minutes
    if oldest = DelayedJob.find(:first, :conditions => [ 'run_at <= ? AND locked_at IS NULL AND attempts = 0', Time.now.utc ], :order => :run_at)
      report_hash[:oldest] = (Time.now.utc - oldest.run_at) / 60
    else
      report_hash[:oldest] = 0
    end
    
    if log_path && !log_path.empty?
      generate_log_analysis(log_path)
    else
      return error("A path to the Delayed Job log file wasn't provided.","Please provide the full path to the Delayed Job log file to analyze (ie - /var/www/apps/APP_NAME/log/delayed_job.log)")
    end
  end
  
  private
  
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
    
    begin
      analysis = analyze(last_summary, now, log_path)
      
      summary( :command => "request-log-analyzer --after '"                   +
                           last_summary.strftime('%Y-%m-%d %H:%M:%S')         +
                           "' --before '" + now.strftime('%Y-%m-%d %H:%M:%S') +
                           " '#{DELAYED_JOB_RLA_FORMAT}' " +
                           " '#{log_path}'",
               :output  => analysis )
    rescue MissingSourceFile
      error("Please update to the latest Request Log Analyzer Gem", "Delayed Job summary reports require request-log-analyzer 1.5.4 or greater. Please upgrade (sudo gem install request-log-analyzer).")
      remember(:last_summary_time, nil) # so it runs next time
    end  
  rescue Exception => error
    error("#{error.class}:  #{error.message}", error.backtrace.join("\n"))
  end

  def analyze(last_summary, stop_time, log_path)
    log_file = read_backwards_to_timestamp(log_path, last_summary)
    summary = StringIO.new
    RequestLogAnalyzer::Controller.build(
      :format       => DELAYED_JOB_RLA_FORMAT,
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

    include RequestLogAnalyzer::Output::FixedWidth::Monochrome

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
