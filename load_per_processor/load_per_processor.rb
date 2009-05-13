#
# Modified load_averages to show load/processor, as this is a more accurate
# measurement of CPU utilization.
#
# Requires /proc/cpuinfo
#
class LoadPerProcessor < Scout::Plugin
  TEST_USAGE = "#{File.basename($0)} max_load MAX_LOAD"

   def build_report
     if `uptime` =~ /load average(s*): ([\d.]+)(,*) ([\d.]+)(,*) ([\d.]+)\Z/
       report :last_minute          => $2.to_f/processors,
              :last_five_minutes    => $4.to_f/processors,
              :last_fifteen_minutes => $6.to_f/processors
     else
       raise "Couldn't use `uptime` as expected."
     end
  rescue Exception
    error "Error determining load", $!.message
  end

  def processors
    processors = memory(:processors)
    unless processors && processors > 0
      if `cat /proc/cpuinfo | grep 'model name' | wc -l` =~ /(\d+)/
        processors = $1.to_i
      else
        raise "Couldn't use /proc/cpuinfo as expected."
      end
      raise "Couldn't use /proc/cpuinfo as expected." unless processors > 0
    end
    remember(:processors, processors)
    return processors
  end

end
