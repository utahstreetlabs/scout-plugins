class OpSourceCloudFiles < Scout::Plugin
  needs 'net/http'                          
  needs 'crack'   
                
  OPTIONS=<<-EOS
  username:                           
    name: Account Username
    default:
  password:               
    name: Account Password
    default:
  EOS
  
  CLOUD_FILES_URI="https://cf-na-east-01.opsourcecloud.net/v2/account"
  
  def build_report                                           
    uri = URI.parse(CLOUD_FILES_URI)
    response = http(uri).request(request(uri.path))
    report = report_from_info(Crack::XML.parse(response.body))
    report(report)
  end
  
  private

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

  def request(path)
    req = Net::HTTP::Get.new(path)
    req.basic_auth(option('username'), option('password'))
    req
  end
  
  def mb(amount)
    amount.to_f / 1024000
  end
end