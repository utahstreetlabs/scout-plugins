# Provide a comma-delimited list of process names (names only, no paths). This plugin checks that at least
# one instance of each named process is running, and alerts you if any of the processes have NO instances running.
# It alerts you again when one or more of the non-running processes is detected again.
#
# You can also check that a process name exists with a certain substring included in its arguments. For example, to
# check for two instances of node (one with "emailer" in its args, and one with "eventLogger" in its args), set this
# in process_names: node/emailer,node/eventLogger
#
# You can mix and match pure process_names and process_name/args. Note that the process names are always full string matches,
# and the args are always partial string matches.
#
class SimpleProcessCheck < Scout::Plugin

  OPTIONS=<<-EOS
    process_names:
      notes: "comma-delimited list of process names to monitor. Example: sshd,apache2,node/eventLogger"
    ps_command:
      label: ps command
      default: ps -eo comm,args
      notes: Leave the default in most cases.
      attributes: advanced
  EOS

  def build_report
    process_names=option(:process_names)
    if process_names.nil? or process_names == ""
      return error("Please specify the names of the processes you want to monitor. Example: sshd,apache2")
    end

    ps_output = `#{option(:ps_command)}`

    unless $?.success?
      return error("Couldn't use `ps` as expected.", error.message)
    end

    # this makes ps_output an array of two-element arrays:
    # [ ["smtpd", "smtpd -n smtp -t inet -u -c"],
    #   ["proxymap", "proxymap -t unix -u"],
    #   ["apache2", "usr/sbin/apache2 -k start"] ]
    ps_output=ps_output.downcase.split("\n").map{|line| line.split(/\s+/,2)}

    processes_to_watch = process_names.split(",").uniq
    process_counts = processes_to_watch.map do |p|
      name, arg_string = p.split("/").map{|s|s.strip}
      if arg_string
        res = ps_output.select{|row| row[0] == name && row[1].include?(arg_string) }.size
      else
        res = ps_output.select{|row| row[0] == name }.size
      end
      res
    end

    num_processes=processes_to_watch.size
    num_processes_present = process_counts.count{|count| count > 0}

    previous_num_processes=memory(:num_processes)
    previous_num_processes_present=memory(:num_processes_present)

    # alert if the number of processes monitored or the number of processes present has changed since last time
    if num_processes !=previous_num_processes || num_processes_present != previous_num_processes_present
      subject = "Process check: #{num_processes_present} of #{processes_to_watch.size} processes are present"
      body=""
      processes_to_watch.each_with_index do |process,index|
        body<<"#{index+1}) #{process} - #{process_counts[index]} instance(s) running  \n"
      end
      alert(subject,body)
    end

    remember :num_processes => num_processes
    remember :num_processes_present => num_processes_present

    report(:processes_present => num_processes_present)
  end
end
