class ModPagespeedMonitoring < Scout::Plugin
  needs 'open-uri'
  needs 'yaml'
  
  OPTIONS=<<-EOS
    url:
      default: http://localhost/mod_pagespeed_statistics
      name: URL
      notes: URL for mod_pagespeed statistics
  EOS

  def build_report
    if option(:url).nil?
      return error("Please provide a url to mod_pagespeed_statistics","By default, the statistics are served from http://localhost/mod_pagespeed_statistics.")
    end
    body = open(option(:url))

    stats=YAML.load(body)
    
    # each of these stats is from startup. calculate the rate. 
    stats.each do |name,value|
      next if !TRACKED.include?(name)
      counter(name, value.to_i, :per => :minute)
    end
  rescue Errno::ECONNREFUSED
    error("Unable to connect to Apache","The connection to #{option(:url)} was refused.")
  rescue OpenURI::HTTPError
    error("mod_pagespeed stats page not found","The URL to the statistics page (#{option(:url)}) was not found.")
  end
  
  # A maximum of 20 metrics can be reported per-scout plugin. 
  # Tracking 13 to leave room for later.
  TRACKED = %w(
    css_file_count_reduction 
    css_filter_files_minified 
    css_filter_minified_bytes_saved 
    css_filter_parse_failures
    css_elements 
    image_inline
    image_rewrite_saved_bytes
    image_rewrites
    javascript_blocks_minified
    javascript_bytes_saved
    javascript_minification_failures
    javascript_total_blocks
    page_load_count
  )
end