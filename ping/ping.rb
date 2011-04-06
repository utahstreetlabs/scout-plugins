# Takes an IP or hostname. Reports 1 if it can ping the host, 0 if it can't
class Ping < Scout::Plugin

  OPTIONS=<<-EOS
  host:
    name: Host
    notes: the IP address or hostname to ping
  EOS

  def build_report
    host = option('host')
    error("You must provide an IP or host to ping") and return if !host

    ping = `ping -c1 #{host} 2>&1`
    res = ping.include?("bytes from") ? 1 : 0
    report(:status=>res)

  end
end
