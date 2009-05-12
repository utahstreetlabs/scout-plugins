class Apache2Status < Scout::Plugin
  STATUS = %|Apache Server Status for localhost

  Server Version: Apache/2.2.8 (Ubuntu) Phusion_Passenger/2.2.2
  Server Built: Jun 25 2008 13:51:29

  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Current Time: Tuesday, 12-May-2009 00:47:32 UTC
  Restart Time: Tuesday, 12-May-2009 00:44:25 UTC
  Parent Server Generation: 1
  Server uptime: 3 minutes 6 seconds
  12 requests currently being processed, 64 idle workers

  _____KK_________K________.......................................
  ____W__WK____K_________K_.......................................
  _____WK_K________________.......................................
  ................................................................
  ................................................................
  ................................................................
  ................................................................
  ................................................................
  ................................................................
  ................................................................
  ................................................................
  ................................................................
  ................................................................
  ................................................................
  ................................................................
  ................................................................

  Scoreboard Key:
  "_" Waiting for Connection, "S" Starting up, "R" Reading Request,
  "W" Sending Reply, "K" Keepalive (read), "D" DNS Lookup,
  "C" Closing connection, "L" Logging, "G" Gracefully finishing,
  "I" Idle cleanup of worker, "." Open slot with no current process
|

PROCESS_LIST = %|www-data  1053  0.0  0.0 122148  2169 ?        S    00:44   0:00 /usr/sbin/apache2 -k start
www-data  1055  0.0  0.1 410437  5528 ?        Sl   00:44   0:01 /usr/sbin/apache2 -k start
www-data  1058  0.0  0.1 475576  5364 ?        Sl   00:44   0:01 /usr/sbin/apache2 -k start
www-data  1242  0.0  0.1 344640  5516 ?        Sl   00:47   0:01 /usr/sbin/apache2 -k start
root     30241  0.0  0.1 122148  4400 ?        Ss   May11   0:00 /usr/sbin/apache2 -k start
|
  def build_report
    results = STATUS || `apache2ctl status`
    
    requests_being_processed = results.match(/([0-9]*) requests currently being processed/)[1].to_i
    report(:requests_being_processed => requests_being_processed)
    
    process_list = (PROCESS_LIST || `ps aux | grep apache2 | grep -v grep | grep -v ruby`).split("\n")
    
    
    memory_size = 0
    process_list.collect! do |line|
      memory_size += line.split(" ")[4].to_i
    end
    
    report(:apache_reserved_memory_size => memory_size.to_s + " bytes")
  end
end