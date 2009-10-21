require "time"
require "stringio"

class ApacheAnalyzer < Scout::Plugin
  ONE_DAY    = 60 * 60 * 24

  needs "elif"
  needs "request_log_analyzer"

  def build_report
    patch_elif

    log_path = option(:log)
    format = option(:format) || 'common'
    request_count = 0
    report_data = { :request_rate     => 0 }
    last_run = memory(:last_request_time) || Time.now

    # read backward, counting lines
    Elif.foreach(log_path) do |line|
      if line =~ /\[(\d{2}\/[A-Za-z]{3}\/\d{4}.\d{2}:\d{2}:\d{2})(?: .\d{4})?\]/
        time_of_request = Time.parse($1)
        if time_of_request < last_run
          break
        else
          request_count += 1
        end
      end

    end

    # calculate request_rate
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

    end

    # report data
    remember(:last_request_time, Time.now)
    report(report_data)    

    if log_path && !log_path.empty?
      generate_log_analysis(log_path, format)
    else
      return error("A path to the Apache log file wasn't provided.","Please provide the full path to the Apache log file to analyze (ie - /var/www/apps/APP_NAME/log/access_log)")
    end
  end

  private

  def silence
    old_verbose, $VERBOSE, $stdout = $VERBOSE, nil, StringIO.new
    yield
  ensure
    $VERBOSE, $stdout = old_verbose, STDOUT
  end

  def generate_log_analysis(log_path, format)
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

    analysis = analyze(last_summary, now, log_path, format)

    summary( :command => "request-log-analyzer --after '"                   +
                         last_summary.strftime('%Y-%m-%d %H:%M:%S')         +
                         "' --before '" + now.strftime('%Y-%m-%d %H:%M:%S') +
                         "' --apache-format "+format +
                         " '#{log_path}'",
             :output  => analysis )
  rescue Exception => error
    error("#{error.class}:  #{error.message}", error.backtrace.join("\n"))
  end

  def analyze(last_summary, stop_time, log_path, format)
    log_file = read_backwards_to_timestamp(log_path, last_summary)
    summary = StringIO.new
    RequestLogAnalyzer::Controller.build(
      :format       => { :apache => format },
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
