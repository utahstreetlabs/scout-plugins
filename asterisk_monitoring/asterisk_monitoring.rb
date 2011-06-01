class MonitorAsterisk < Scout::Plugin

 def get_core_channels
   lines = `/usr/sbin/asterisk -rx 'core show channels'`.split("\n")
   channel_lines = lines.select {|l| l =~ /active channels/}
   call_lines = lines.select {|l| l =~ /active calls/}
   call_lines[0].squeeze(" ").split(" ")
   @report_hash[:active_channels] = channel_lines[0].squeeze(" ").split(" ")[0].to_i
   @report_hash[:active_calls] = call_lines[0].squeeze(" ").split(" ")[0].to_i
 end

 def get_sip_peers
   lines = `/usr/sbin/asterisk -rx 'sip show peers'`.split("\n")
   sip_online_peers = lines.select {|l| l =~ /OK/}
   @report_hash[:sip_agents] = sip_online_peers.select {|l| l =~ /^\d/}.count
   @report_hash[:sip_trunks] = sip_online_peers.select {|l| l =~ /^\D/}.count
 end

 def build_report
   @report_hash={}
   get_core_channels
   get_sip_peers
   report(@report_hash)
 end

end