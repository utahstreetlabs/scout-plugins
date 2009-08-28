require "time"
require "digest/md5"

# Log Tail plugin for Scout.
# based heavily on the MySQL Slow Queries Monitoring plugin

class ScoutLogTail < Scout::Plugin
  needs "elif"

  def build_report
    log_file_path = option("logfile").to_s.strip
    if log_file_path.empty?
      return error( "A path to the a log file wasn't provided." )
    end

    log_lines_count = 0
    last_run = memory(:last_run) || Time.now
    current_time = Time.now
    Elif.foreach(log_file_path) do |line|
      if line =~ Regexp.new(option("date_regex").to_s.strip)
        t = Time.parse($1)
        t2 = last_run
        if t < t2
          break
        else
          regex = Regexp.new(option("alert_regex").to_s.strip)
          if regex =~ line
            log_lines_count = log_lines_count + 1
            alert(:subject => log_file_path, :body => line)
          end
        end
      end
    end

    elapsed_seconds = current_time - last_run
    logger.info "Current Time: #{current_time}"
    logger.info "Last run: #{last_run}"
    logger.info "Elapsed: #{elapsed_seconds}"
    elapsed_seconds = 1 if elapsed_seconds < 1
    logger.info "Elapsed after min: #{elapsed_seconds}"
    logger.info "count: #{log_lines_count}"
    # calculate per-second
    report(:lines => log_lines_count/(elapsed_seconds/60.to_f))
    remember(:last_run,Time.now)
  end
end
