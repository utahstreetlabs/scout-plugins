# Apache2 Status by Hampton Catlin
# Modified by Jesse Newland
#
# Free Use Under the MIT License
#
# Please note, your server must respond to "apache2ctl status"
#
class Apache2Status < Scout::Plugin

  OPTIONS=<<-EOS
  apache_status_path:
    default: /usr/sbin/apache2ctl
    name: Full path to the apache2ctl executable
    notes: In most cases you can leave this blank and use the default.
  ps_command:
    name: The Process Status (ps) Command
    default: "ps aux | grep apache2 | grep -v grep | grep -v ruby | awk '{print $5}'"
    attributes: advanced
    notes: Expected to return a list of the size of each apache process, separated by newlines. The default works on most systems.
  EOS


  def build_report
    report(:apache_reserved_memory_size => apache_reserved_memory_size)
    apache_status
    report(
      :requests_being_processed => requests_being_processed,
      :idle_workers => idle_workers,
      :requests_sec => requests_sec,
      :kb_second => kB_second,
      :b_request => b_request
    )
  end
  
  # Calculate the total reserved memory size from a ps aux with a couple greps
  def apache_reserved_memory_size
    memory_size = shell("#{ps_command}").split("\n").inject(0) { |i,n| i+= n.to_i; i }

    # Calculate how many MB that is
    ((memory_size / 1024.0) / 1024).to_f
  end

  def ps_command
    option(:ps_command) || "ps aux | grep apache2 | grep -v grep | grep -v ruby | awk '{print $5}'"
  end

  def apache_status_path
    option(:apache_status_path) || "/usr/sbin/apache2ctl"
  end

  def apache_status
    # Must have mod_status installed
    @apache_status = shell("#{apache_status_path} status")
    if $?.success?
      @apache_status
    else
      error("Couldn't use `#{apache_status_path}` as expected.", @apache_status)
    end
  end

  def b_request
    @apache_status.match(/([0-9]*) B\/request/)[1].to_f
  end

  def kB_second
    res=0
    if match=@apache_status.match(/([0-9]*\.[0-9]*) kB\/second/) # output is sometimes in kB
      res=match[1].to_f
    elsif match=@apache_status.match(/(\d+) B\/second/) # output is sometimes in bytes
      res=match[1].to_f/1024.0
    end
    res
  end

  def requests_sec
    @apache_status.match(/([0-9]*\.[0-9]*) requests\/sec/)[1].to_f
  end

  def idle_workers
    @apache_status.match(/([0-9]*) idle workers/)[1].to_i
  end

  def requests_being_processed
    @apache_status.match(/([0-9]*) requests currently being processed/)[1].to_i
  end

  # Use this instead of backticks. It's made a separate method so it can be stubbed
  def shell(cmd)
    res = `#{cmd}`
  end
end