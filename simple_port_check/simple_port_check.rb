require 'socket'

# Provide a host and a comma-delimited list of ports. This plugin will alert you when the status
# of one or ports changes (a port that was previously online goes offline, or vice-versa).
class SimplePortCheck < Scout::Plugin

  OPTIONS=<<-EOS
    host:
      notes: the host on which to check ports
      default: localhost
    ports:
      notes: comma-delimited list of ports to monitor
      default: "80,25"
  EOS

  def build_report
    host = option(:host)
    ports = option(:ports).split(/[ ,]+/).map(&:to_i).uniq
    port_status=ports.map{|port| is_port_open?(host, port)} # true=open, false=closed

    num_ports=ports.size
    num_ports_open = port_status.count{|status| status}

    previous_num_ports=memory(:num_ports)
    previous_num_ports_open=memory(:num_ports_open)

    # alert if the number of ports monitored or the number of ports open has changed since last time
    if num_ports !=previous_num_ports || num_ports_open != previous_num_ports_open
      subject = "Port check: #{num_ports_open} of #{ports.size} ports open"
      body="Port status on #{host}:\n"
      ports.each_with_index do |port,index|
        body<<" #{port}: #{port_status[index] ? 'open' : 'CLOSED'} \n"
      end
      alert(subject,body)
    end

    remember :num_ports => num_ports
    remember :num_ports_open => num_ports_open
    
    report(:num_ports_open => num_ports_open)
  end

  private

  def is_port_open?(host,port)
    begin
      s = TCPSocket.open(host, port)
      s.close
      true
    rescue
      false
    end
  end
end
