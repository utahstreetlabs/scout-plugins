# Apache2 Status by Hampton Catlin
# Modified by Jesse Newland
#
# Free Use Under the MIT License
class Apache2Status < Scout::Plugin
  needs "net/http", "uri"

  OPTIONS=<<-EOS
  server_url:
    name: Server Status URL
    notes: Specify URL of the server-status page to check. Scout requires the machine-readable format of the status page (just add '?auto' to the server-status page URL).
    default: "http://localhost/server-status?auto"
  ps_command:
    name: The Process Status (ps) Command
    default: "ps aux | grep apache2 | grep -v grep | grep -v ruby | awk '{print $5}'"
    attributes: advanced
    notes: Expected to return a list of the size of each apache process, separated by newlines. The default works on most systems.
  EOS


  def build_report
    report('apache_reserved_memory_size' => apache_reserved_memory_size)
    apache_status
    apache_status.each do |key, value|
      begin
        report(underscore(key).gsub(/ /, '_') => value.to_f)
      rescue Exception => e
        error("Error reporting #{key} => #{value}")
      end
    end
  end
  
  # Calculate the total reserved memory size from a ps aux with a couple greps
  def apache_reserved_memory_size
    memory_size = shell("#{ps_command}").split("\n").inject(0) { |i,n| i+= n.to_i; i }

    # Calculate how many MB that is
    ((memory_size / 1024.0) / 1024).to_f
  end

  def ps_command
    option(:ps_command) || "ps aux | grep apache2 | grep -v grep | grep -v ruby | awk '{print $5}'"
  end

  def apache_status_uri
    @apache_status_uri ||= (option("server_url") || 'http://localhost/server-status?auto')
  end

  def apache_status
    begin
      url = URI.parse(apache_status_uri)
      req = Net::HTTP::Get.new(url.path + "?" + url.query.to_s)
      res = Net::HTTP.start(url.host, url.port) {|http|
        http.request(req)
      }
      apache_status = YAML.load(res.body) rescue {}
      raise ScriptError, "YAML parsing of #{res.body} failed" unless apache_status['Scoreboard'] && apache_status.delete('Scoreboard')
      @apache_status = apache_status
    rescue Exception => e
      error("Error parsing #{apache_status_uri}", e.message)
    end
  end

  # From rails:
  # https://github.com/rails/rails/raw/master/activesupport/lib/active_support/inflector/methods.rb
  # Makes an underscored, lowercase form from the expression in the string.
  #
  # Changes '::' to '/' to convert namespaces to paths.
  #
  # Examples:
  #   "ActiveRecord".underscore         # => "active_record"
  #   "ActiveRecord::Errors".underscore # => active_record/errors
  #
  # As a rule of thumb you can think of +underscore+ as the inverse of +camelize+,
  # though there are cases where that does not hold:
  #
  #   "SSLError".underscore.camelize # => "SslError"
  def underscore(camel_cased_word)
    word = camel_cased_word.to_s.dup
    word.gsub!(/::/, '/')
    word.gsub!(/([A-Z]+)([A-Z][a-z])/,'\1_\2')
    word.gsub!(/([a-z\d])([A-Z])/,'\1_\2')
    word.tr!("-", "_")
    word.downcase!
    word
  end

  # Use this instead of backticks. It's made a separate method so it can be stubbed
  def shell(cmd)
    res = `#{cmd}`
  end

end