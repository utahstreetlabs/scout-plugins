# To test with the sample file, pass sample=true as an option.
class HaproxyStats < Scout::Plugin

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
    notes: URI of the haproxy CSV stats url. See the 'CSV Export' link on your haproxy stats page
    default: http://yourdomain.com/;csv
  EOS

  def build_report

    if option(:uri) == ''
      return error('URI to HAProxy Stats Required', "It looks like the URI to the HAProxy stats page (in csv format) hasn't been provided. Please enter this URI in the plugin settings.")
    end

    begin
      FasterCSV.parse(open(option(:uri)), :headers => true) do |row|
        if row["svname"] == 'FRONTEND' || row["svname"] == 'BACKEND'
          name = row["# pxname"] + ' ' + row["svname"].downcase
          report "#{name} Current Sessions" => row["scur"]
          report "#{name} Current Queue" => row["qcur"] unless row["qcur"].nil?
          report "#{name} Requests / second" => row["rate"] unless row["rate"].nil?
        end
      end
    rescue FasterCSV::MalformedCSVError
      return error('Error accessing stats page', "The plugin encountered an error attempting to access the stats page (in CSV format) at: #{option(:uri)}. The exception: #{$!.message}\n#{$!.backtrace}")
    end
  end
  
end
