# Monitors Multi-Master Replication Manager for MySQL (MMM), parsing the output of the 
# "mmm_control show" command (http://mysql-mmm.org/mmm1:how-to-use#show). 
#
# The number of databases in each state is reported. If a db changes state an alert is generated.
class MySQLMMM < Scout::Plugin
  
  STATES = %w(ONLINE AWAITING_RECOVERY ADMIN_OFFLINE HARD_OFFLINE REPLICATION_FAIL REPLICATION_DELAY)
  
  def build_report
    output = `sudo mmm_control show`
    reports = Hash.new
    current_states = Hash.new
    previous_states = memory(:previous_states)
    STATES.each { |s| reports[s] = 0 }
    output.lines.each do |l|
      STATES.each do |s| 
        if l.include?(s) 
          reports[s] +=1
          db = l.strip.match(/^\w+/)[0]
          current_states[db] = s
          if previous_states and previous_states[db] and previous_states[db] != s
            alert("#{db} status changed to #{s}", "#{db} state has changed from #{previous_states[db]} to #{s}")
          end
        end
      end
    end 
    report(reports)
    remember(:previous_states => current_states)
  end
end