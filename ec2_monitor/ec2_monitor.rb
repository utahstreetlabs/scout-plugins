class Ec2Monitor < Scout::Plugin

  OPTIONS=<<-EOS
    ping_destination:
      notes: "ping internal IP of server you're dependant on.  blank skips the test"
    ebs_device:
      note: eg. 'sdi'.  await - The average time (in milliseconds) for I/O requests issued to the device to be served. This includes the time spent by the requests in queue and the time spent servicing them.  svctime - The average service time (in milliseconds) for I/O requests that were issued to the device. avgqu-sz - The average queue length of the requests that were issued to the device
      default: sdi
  EOS
  
  NO_IOSTAT_ERROR = "iostat error"

  def build_report
    begin
      ping_avg, ping_max = parse_ping_output
      avgqu_sz, await, svctm = ebs_timing
       ping_report = {:ping_avg => ping_avg, :ping_max => ping_max}
       ebs_report = {:ebs_queue => avgqu_sz, :ebs_wait => await, :ebs_service => svctm }
       steal_report = {:steal => steal_percentage}
       combined_report = steal_report
       combined_report = combined_report.merge( ping_report ) if ping_avg && ping_max
       combined_report = combined_report.merge( ebs_report ) if avgqu_sz && avgqu_sz.size > 0
       report combined_report
    rescue StandardError => e
      if e.message == NO_IOSTAT_ERROR
        error("Please install iostat","It looks like the sysstat package may not be installed on this server. The iostat command used by this plugin is included in sysstat.\n\nFor example, to install on Ubuntu: apt-get install sysstat")
      else
        raise
      end
    end
  end

  def steal_percentage
      steal_percentage = `iostat -c | tail -2  | awk '{print $5}' | head -1`
      steal_percentage.chomp
  end

  def parse_ping_output
    return nil, nil unless ping_destination.size > 0
    data = `ping -c 2 -s 1500 #{ping_destination} | tail -1 | awk '{print $4}'`
    # rtt min/avg/max/mdev = 0.490/0.564/0.663/0.062 ms
    return nil, nil unless data && data.size > 0
    values = data.split('/')
    avg = values[1]
    max = values[2]
    return avg, max
  end
  
  # http://www.igvita.com/2009/06/23/measuring-optimizing-io-performance/
  #  await - The average time (in milliseconds) for I/O requests issued to the device to be served. This includes the time spent by the requests in queue and the time spent servicing them.
  #  svctime - The average service time (in milliseconds) for I/O requests that were issued to the device.
  #  avgqu-sz - The average queue length of the requests that were issued to the device
  def ebs_timing
    iostat_output = `iostat -x`
    puts iostat_output.to_i
    unless $?.to_i.zero? # checking to see if process existed w/an error
      raise NO_IOSTAT_ERROR
    end
    avgqu_sz = `echo #{iostat_output} | grep #{ebs_device} | awk '{print $9}'`
    await = `echo #{iostat_output} | grep #{ebs_device} | awk '{print $10}'`
    svctm = `echo #{iostat_output} | grep #{ebs_device} | awk '{print $11}'`
    return avgqu_sz.chomp, await.chomp, svctm.chomp
  end


  def ping_destination
      option(:ping_destination) || ''
  end

  def ebs_device
      option(:ebs_device) || 'sdi'
  end

end
