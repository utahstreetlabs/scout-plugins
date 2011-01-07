class CouchDBOverallMonitoring< Scout::Plugin
  OPTIONS = <<-EOS
      couchdb_port:
        label: The port that CouchDB is running on
        default: 5984
      couchdb_host:
        label: The host that CouchDB is running on
        default: http://127.0.0.1
    EOS

    needs 'open-uri', 'json', 'facets'
    
    METRICS = %w{database_reads database_writes}
    HTTP_REQUEST_METHODS = %w{GET POST PUT DELETE}
    HTTP_STATS = %w{requests view_reads}
    
    def build_report
      if option(:couchdb_host).nil? or option(:couchdb_port).nil?
        return error("Please provide the host & port", "The Couch DB Host and Port is required.\n\nCouch DB Host: #{option(:couchdb_host)}\n\nCouch DB Port: #{option(:couchdb_port)}")
      end
      @base_url = "#{option(:couchdb_host)}:#{option(:couchdb_port)}/"

      report_server_status
      # report_http_responses
      report_http_methods
      report_http_stats
    rescue OpenURI::HTTPError
      error("Metric not found","Please ensure the base url for Couch DB Metrics is correct. Current URL: \n\n#{@base_url}")
    rescue SocketError
      error("Hostname is invalid","Please ensure the Couch DB Host is correct - the host could not be found. Current URL: \n\n#{@base_url}")
    end
    
    def report_server_status
      METRICS.each do |metric|
        response = JSON.parse(open(@base_url + "_stats/couchdb/#{metric}").read)
        count = response['couchdb'][metric].ergo['current'] || 0
        counter(metric,count.to_i,:per => :second)
      end
    end
    
    def report_http_responses
      success_codes = %w{200 201 202 301 304}
      error_codes = %w{400 401 403 404 405 409 412 500}
      # TOOO - need to sum up codes and report
      http_status_codes.each do |status_code|
        key = "httpd_status_codes_#{status_code}_count".to_sym
        response = JSON.parse(Net::HTTP.get(URI.parse(base_url + "_stats/httpd_status_codes/#{status_code}")))
        count = response['httpd_status_codes'][status_code].ergo['current'] || 0
        report(key => count - (memory(key) || 0))
        remember(key, count)
      end
    end
    
    def report_http_methods
      HTTP_REQUEST_METHODS.each do |http_method|
        response = JSON.parse(open(@base_url + "_stats/httpd_request_methods/#{http_method}").read)
        count = response['httpd_request_methods'][http_method].ergo['current'] || 0
        counter(http_method,count.to_i,:per => :second)
      end
    end
    
    def report_http_stats
      HTTP_STATS.each do |metric|
        response = JSON.parse(open(@base_url + "_stats/httpd_request_methods/#{metric}").read)        
        count = response['httpd'][metric].ergo['current'] || 0
        counter(metric,count.to_i,:per => :second)
      end
    end
end