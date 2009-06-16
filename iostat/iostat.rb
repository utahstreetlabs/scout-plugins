class Iostat < Scout::Plugin
  def build_report
    
    # Using the second reading- avg since previous check
    stats = iostat_output.grep(/#{device}/).last.split
    
    # Expected output format: 
    #Device:         rrqm/s   wrqm/s     r/s     w/s    rkB/s    wkB/s avgrq-sz avgqu-sz   await  svctm  %util
    #xvda1             0.00     0.00    0.00    0.00     0.00     0.00     0.00     0.00    0.00   0.00   0.00 
    report(
      :rps     => stats[3], 
      :wps     => stats[4],
      :rkbps   => stats[5],
      :wkbps   => stats[6],
      :await   => stats[9],
      :util    => stats[11]
    )
    
  rescue Exception => e
    error "Unexpected output format: #{e}"
    logger.error 'Got invalid output:'
    logger.error iostat_output
  end
  
  private

  def iostat_output
    command = option('command') || 'iostat -dxk'
    interval = option('interval') || 3
    iostat_command = "#{command} #{interval} 2"
    @output ||= `#{iostat_command}`
  end
  
  def device
    option('device') || `mount`.grep(/ \/ /)[0].split[0].split('/').last
  end
  
end