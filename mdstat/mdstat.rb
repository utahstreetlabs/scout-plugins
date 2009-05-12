# =================================================================================
# mdstat
# 
# Created by Mark Hasse on 2008-04-15.
# =================================================================================

=begin
Personalities : [raid1] 
md1 : active raid1 sda1[0] sdc1[2](S) sdb1[1]
      244195904 blocks [2/2] [UU]
      
unused devices: <none>
=end

class MdStat < Scout::Plugin
  def build_report
    data          = Hash.new 
    data = Hash.new
         
    mdstat = IO.readlines('/proc/mdstat')
    
    spares = mdstat[1].scan(/\(S\)/).size
    failed = mdstat[1].scan(/\(F\)/).size

    mdstat[2] =~ /\[(\d*\/\d*)\].*\[(.+)\]/
    counts = $1
    status = $2
    
    disk_counts = counts.split('/').map { |x| x.to_i } 
    disk_status = status.squeeze
    
    if disk_counts[0].class == Fixnum && disk_counts[1].class == Fixnum
      data[:active_disks] = disk_counts[0]
      data[:spares]       = spares
      data[:failed_disks] = failed
    else
      raise "Unexpected mdstat file format"
    end 
    
    if disk_counts[0] != disk_counts[1] || disk_status != 'U' || failed > 0 
      if memory(:mdstat_ok)
        remember(:mdstat_ok,false)
        alert(:subject => 'Disk failure detected')
      end
    else
      remember(:mdstat_ok,true)
    end

    report(data)
  rescue
    error(:subject => "Couldn't parse /proc/mdstat as expected.", :body => $!.message)
  end
end