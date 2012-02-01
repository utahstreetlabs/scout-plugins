# Provide a shell command that yields a number. For Example:
#
#     ls -1 /Users/andre | wc -l
#
# If you want the resulting metric to have a name, place the name after a comment (#):
#
#     ls -1 /Users/andre | wc -l # num_files_in_home
#
# For multiple commands, separate with a semicolon:
#
#     ps -ef | grep ruby | wc -l # num_ruby_processes; ls -1 /Users/andre | wc -l # files_in_directory
#
# Notes:
# * to configure this plugin, download a local copy and try in test mode! Example:
#   scout test generic_shell_command.rb args="ls -1 /some/dir | wc -l"
# * all results will be cast to integers. If you forget to pipe to wc, you will get unexpected results
# * make sure you know what you're doing with this plugin!

class GenericShellCommand < Scout::Plugin
  OPTIONS=<<-EOS
  args:
    name: args
    notes: "one or more shell commands, in the format 'command_1 #optional_label; command_2 #label2' "
  EOS

  def build_report
    res={}
    lines = (option(:args) || "").split(";")
    lines.each_with_index do |line,i|
      command,label=line.split("#",2).map{|s|s.strip}
      label = (label && label != "") ? label.gsub(/\W+/,'_') : "value_#{i+1}"
      res[label]=`#{command}`.strip.to_i
    end
    report res
  end
end
