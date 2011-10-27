

# Provide a comma-delimited list of process names (names only, no paths). This plugin checks that at least
# one instance of each named process is running, and alerts you if any of the processes have NO instances running.
# It alerts you again when one or more of the non-running processes is detected again.
class ProcessUsage < Scout::Plugin

  OPTIONS=<<-EOS
    process_names:
      notes: "comma-delimited list of process names to monitor. Example: sshd,apache2"
    ps_command:
      label: ps command
      default: ps axco command
      notes: Leave the default in most cases. The commmand should return all processes running, one line per process, without any other info.
  EOS

  def build_report
    process_names=option(:process_names)
    if process_names.nil? or process_names == ""
      return error("Please specify the names of the processes you want to monitor. Example: sshd,apache2")
    end
    ps_command   = option(:ps_command) || "ps axco command"

    ps_output = `#{ps_command}`
    unless $?.success?
      return error("Couldn't use `ps` as expected.", error.message)
    end

    ps_output=ps_output.downcase.split("\n")


    processes=process_names.split(",").uniq
    process_counts=processes.map{|name| ps_output.count{|line_item|line_item==name} }

    num_processes=processes.size
    num_processes_present = process_counts.count{|count| count > 0}

    previous_num_processes=memory(:num_processes)
    previous_num_processes_present=memory(:num_processes_present)

    # alert if the number of processes monitored or the number of processes present has changed since last time
    if num_processes !=previous_num_processes || num_processes_present != previous_num_processes_present
      subject = "Process check: #{num_processes_present} of #{processes.size} processes are present"
      body=""
      processes.each_with_index do |process,index|
        body<<"#{index+1}) #{process} - #{process_counts[index]} instance(s) running  \n"
      end
      alert(subject,body)
    end

    remember :num_processes => num_processes
    remember :num_processes_present => num_processes_present

    report(:processes_present => num_processes_present)
  end
end
