require 'socket'

# Provide a comma-delimited list of host:ports. This plugin will alert you when the status
# of one or ports changes (a port that was previously online goes offline, or vice-versa).
class SimplePortCheck < Scout::Plugin

  OPTIONS=<<-EOS
    ports:
      notes: "comma-delimited list of 'host:ports' to monitor. Example: yahoo.com:80,google.com:443"
      default: "localhost:80,google.com:443,yahoo.com:80"
  EOS

  def build_report
    ports = option(:ports).split(/[ ,]+/).uniq
    port_status=ports.map{|port| is_port_open?(port)} # true=open, false=closed

    num_ports=ports.size
    num_ports_open = port_status.count{|status| status}

    previous_num_ports=memory(:num_ports)
    previous_num_ports_open=memory(:num_ports_open)

    # alert if the number of ports monitored or the number of ports open has changed since last time
    if num_ports !=previous_num_ports || num_ports_open != previous_num_ports_open
      subject = "Port check: #{num_ports_open} of #{ports.size} ports open"
      body=""
      ports.each_with_index do |port,index|
        body<<"#{index+1}) #{port} - #{port_status[index] ? 'open' : 'CLOSED'} \n"
      end
      alert(subject,body)
    end

    remember :num_ports => num_ports
    remember :num_ports_open => num_ports_open
    
    report(:num_ports_open => num_ports_open)
  end

  private

  def is_port_open?(host_and_port)
    host,port=host_and_port.split(":")
    begin
      s = TCPSocket.open(host, port.to_i)
      s.close
      true
    rescue
      false
    end
  end
end
