#
# Copyright 2011 Pulse Energy Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
#
# A Scout Plugin for reading JMX values.
#
# Requires: Java SDK and jmxterm [http://wiki.cyclopsgroup.org/jmxterm]
#
class JmxAgent < Scout::Plugin
  OPTIONS=<<-EOS
    jmxterm_uberjar:
      name: jmxterm uberjar File
      notes: Absolute file name of the jmxterm uberjar.

    jvm_pid_file:
      name: JVM PID File
      notes: File from which the PID of the JVM process can be read.
             Optional. If absent, mbean_server_url must be configured.

    mbean_server_url:
      name: MBean Server URL
      notes: The URL can be <host>:<port> or full service URL.
             Optional. If absent, jvm_pid_file must be configured.

    mbeans_attributes:
      name: MBean and Attributes Names
      default: HeapMemoryUsage,NonHeapMemoryUsage@java.lang:type=Memory
      notes: A pipe-delimited list of comma separated attribute names @ MBean name.
      For example: HeapMemoryUsage,NonHeapMemoryUsage@java.lang:type=Memory|Name@java.lang:type=Runtime

    use_bean_namespace:
      name: use bean namespace?
      notes: If set to 'true', prefixes bean names with namespaces
  EOS

  def to_float?(value)
    Float(value)
  rescue
    value
  end

  def parse_attribute_line(line)
    s = line.split(/[=;]/)
    {:name => s[0].strip, :value => to_float?(s[1].strip)}
  end

  def read_mbeans(jmx_cmd, *beans)
    queries = beans.map {|(bean, attributes)| "get --bean #{bean} #{attributes}"}.join(" \ \n")
    command = "echo '#{queries}' | #{jmx_cmd}"
    jmx_result = `#{command} 2>&1`
    if jmx_result.match(/No such PID (\d+)/)
      error("Java PID #{$1} is invalid", "Command: #{command}\n\nResult: #{jmx_result}")
      return {}
    end

    report = {}
    jmx_result.split("\n").select {|line| line.match(/^#InstanceNotFoundException/)}.each do |line|
      report[line.split(': ')[1]] = 'not found'
    end

    jmx_result.split("\n").select {|line| !line.match(/^#InstanceNotFoundException/)}.join("\n").
      split("#mbean = ").drop(1).each_with_object(report) do |bean_results, results|
      (bean, attribute_results) = bean_results.split(":\n")
      (bean_path, attrs) = bean.split(':')
      bean_attrs = Hash[attrs.split(',').map {|kv| kv.split('=')}]
      bean_name = if option(:use_bean_namespace) == 'true'
                    [bean_path, bean_attrs['name']].compact.join('.')
                  else
                    bean_attrs['name']
                  end
      if attribute_results
        if attribute_results.match(/RuntimeMBeanException/)
          results[bean_name] = attribute_results
        else
          attribute_results.strip.split("\n\n").each do |attribute_result|
            (attribute, value) = attribute_result.chomp(';').split(' = ', 2)
            attr_name = [bean_name, attribute].compact.join('.')
            if value[0] == '{'
              value.gsub('{', '').gsub('}', '').strip.split("\n").each do |kv|
                (key, val) = kv.split(' = ')
                results["#{attr_name}.#{key.strip}"] = to_float?(val.chomp(';'))
              end
            else
              results[attr_name] = to_float?(value)
            end
          end
        end
      end
    end
    report
  end

  def build_report
    jvm_pid_file = option(:jvm_pid_file)
    mbean_server_location = option(:mbean_server_url)

    if jvm_pid_file and !jvm_pid_file.empty? then
      jvm_pid = File.open(jvm_pid_file).readline.strip
      mbean_server_location = jvm_pid
    end

    if mbean_server_location.nil? or mbean_server_location.empty?
      return error("A a JMX PID or an MBean Server Url is required",
           "No MBean server location configured: no PID file nor server URL")
    end

    mbeans_attributes = option(:mbeans_attributes)
    return error("No MBeans and Attributes Names defined") if mbeans_attributes.empty?

    jmx_cmd = "java -jar #{option(:jmxterm_uberjar)} -l #{mbean_server_location} -n"

    # validate JVM connectivity
    read_mbeans(jmx_cmd, ['java.lang:type=Runtime', 'Name'])
    return if errors.any?

    # query configured mbeans
    beans = mbeans_attributes.split('|').map do |mbean_attributes|
      s = mbean_attributes.split('@')
      raise "Invalid MBean attributes configuration" unless s.size == 2
      mbean = s[1]
      attributes = s[0].gsub(',', ' ')
      [mbean, attributes]
    end

    report(read_mbeans(jmx_cmd, *beans))
  end
end
