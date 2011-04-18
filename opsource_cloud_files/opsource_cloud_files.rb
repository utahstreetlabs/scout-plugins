class OpSourceCloudFiles < Scout::Plugin
  needs 'net/http'                          
  needs 'crack'   
                
  OPTIONS=<<-EOS
  username:
    notes: User name to use for OpSource Cloud Files account.    
    default:
  password:
    notes: Password to use for OpSource Cloud Files account.
    default:
  EOS
  
  CLOUD_FILES_URI="https://cf-na-east-01.opsourcecloud.net/v2/account"
  
  def build_report                                           
    report(account_info(
      :user => option('username'), 
      :password => option('password')
    ))
  end
  
  private

  def account_info(opts)
    uri = URI.parse(CLOUD_FILES_URI)
    body = http(uri).request(request(uri, opts)).body
    report_from_info(Crack::XML.parse(body))
  end                                    

  def report_from_info(info)
    report = {}       
      
    ['bandwidth', 'storage'].each do |c|
      n = info['account_info'][c]
      n.each_pair do |k,v|
        report["#{c}_#{k}".to_sym] = mb(n[k])
      end
    end
    
    report[:bandwidth_percent_used] = percent_used(report[:bandwidth_total], report[:bandwidth_allocated])
    report[:storage_percent_used] = percent_used(report[:storage_used], report[:storage_allocated])
    report
  end
  
  def percent_used(used, allocated)                                                          
    (used / allocated * 100).ceil
  end
    
  def http(uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http
  end                        

  def request(uri, opts = {})
    req = Net::HTTP::Get.new(uri.path)
    req.basic_auth opts[:user], opts[:password]
    req
  end
  
  def mb(amount)
    amount.to_f / 1024000
  end
end