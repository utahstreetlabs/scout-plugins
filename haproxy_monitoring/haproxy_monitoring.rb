class HaproxyMonitoring < Scout::Plugin

  if RUBY_VERSION < "1.9"
    needs 'fastercsv'
  else
    # typically, avoid require. In this case we can't use needs' deferred loading because we need to alias CSV
    require 'csv'
    FasterCSV=CSV
  end
  needs 'open-uri'

  OPTIONS=<<-EOS
  uri:
    name: URI
    notes: URI of the haproxy CSV stats url. See the 'CSV Export' link on your haproxy stats page.
    default: http://yourdomain.com/;csv
  proxy:
    notes: The name of the proxy to monitor. Proxies are typically listed in the haproxy.cfg file.
  user:
    notes: If protected under basic authentication provide the user name.
  password:
    notes: If protected under basic authentication provide the password.   
    attributes: password
  EOS

  def build_report

    if option(:uri).nil?
      return error('URI to HAProxy Stats Required', "It looks like the URI to the HAProxy stats page (in csv format) hasn't been provided. Please enter this URI in the plugin settings.")
    end
    proxy = option(:proxy)
    possible_proxies = []
    proxy_found = false
    begin
      FasterCSV.parse(open(option(:uri),:http_basic_authentication => [option(:user),option(:password)]), :headers => true) do |row|
        if row["svname"] == 'FRONTEND' || row["svname"] == 'BACKEND'
          possible_proxies << row["# pxname"]
          next unless proxy.to_s.strip.downcase == row["# pxname"].downcase
          proxy_found = true
          counter(:requests, row['stot'].to_i, :per => :minute)
          counter(:errors_req, row['ereq'].to_i, :per => :minute) if row['ereq']     
          counter(:errors_conn, row['econ'].to_i, :per => :minute) if row['econ']       
          counter(:errors_resp, row['eresp'].to_i, :per => :minute) if row['eresp']  
          report(:proxy_up=>%w(UP OPEN).find {|s| s == row['status']} ? 1 : 0)
        end
      end
    rescue OpenURI::HTTPError
      if $!.message == '401 Unauthorized'
        return error("Authentication Failed", "Unable to access the stats page at #{option(:uri)} with the username '#{option(:user)}' and provided password. Please ensure the username, password, and URI are correct.")
      elsif $!.message != '404 Not Found'
        return error("Unable to find the stats page", "The stats page could not be found at: #{option(:uri)}.")
      else
        raise
      end
    rescue FasterCSV::MalformedCSVError
      return error('Unable to access stats page', "The plugin encountered an error attempting to access the stats page (in CSV format) at: #{option(:uri)}. The exception: #{$!.message}\n#{$!.backtrace}")
    end
    if proxy.nil?
      error('Proxy name required',"The name of the proxy to monitor must be provided in the plugin settings. The possible proxies to monitor:\n<ul>#{possible_proxies.map { |p| "<li>#{p}</li>"}.join('')}</ul>")
    elsif !proxy_found
      error('Proxy not found',"The proxy '#{proxy}' was not found. The possible proxies to monitor:\n<ul>#{possible_proxies.map { |p| "<li>#{p}</li>"}.join('')}</ul>")
      
    end
  end
  
end
