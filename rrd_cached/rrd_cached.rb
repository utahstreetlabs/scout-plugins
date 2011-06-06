# Reports stats on the RRDCached Daemon.
class RRDCachedMonitor < Scout::Plugin
  
  OPTIONS = <<-EOS
  host:
    name: Host
    notes: The host to monitor
    default: 127.0.0.1
  port:
    name: Port
    notes: The port rrdcached is running on
    default: 42217
  EOS
  
  # metrics that should be reported as rates
  COUNTERS = %w(UpdatesWritten UpdatesReceived DataSetsWritten FlushesReceived)
  
  def build_report
    s=TCPSocket.new(option(:host),option(:port))
    s.puts "STATS"
    output = String.new
    
    first_line = s.gets
    # first_line = 9 Statistics follow
    # metric sample: QueueLength: 0
    first_line.to_i.times { output << s.gets }
    s.close
    
    data = {}
    output.lines.each do |l|
      metric,value = l.split(':')
      if COUNTERS.include?(metric)
        counter(metric, value.to_i, :per => :minute)
      else
        data[metric] = value.to_i 
      end
    end
    report(data)
  end
end