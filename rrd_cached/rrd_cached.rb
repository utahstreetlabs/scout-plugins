# Reports stats on the RRDCached Daemon.
class RRDCachedMonitor < Scout::Plugin
  
  OPTIONS = <<-EOS
  location:
    name: UNIX Socket Location
    default: "/tmp/rrdcached.sock"
  EOS
  
  # metrics that should be reported as rates
  COUNTERS = %w(UpdatesWritten UpdatesReceived DataSetsWritten FlushesReceived)
  
  def build_report
    s=UNIXSocket.new(option(:location))
    s.puts "STATS"
    output = String.new
    
    first_line = s.gets
    # first_line = 9 Statistics follow
    # metric sample: QueueLength: 0
    first_line.to_i.times { output << s.gets }
    s.close
    
    data = {}
    output.each_line do |l|
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