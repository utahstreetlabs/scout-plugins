class HaproxyStats < Scout::Plugin

  needs 'fastercsv', 'open-uri'

  OPTIONS=<<-EOS
  uri:
    name: URI
    notes: URI of the haproxy CSV stats url. See the 'CSV Export' link on your haproxy stats page
  EOS

  def build_report
    FasterCSV.parse(open(option(:uri)), :headers => true) do |row|
      if row["svname"] == 'FRONTEND' || row["svname"] == 'BACKEND'
        name = row["# pxname"] + ' ' + row["svname"].downcase
        report "#{name} Current Sessions" => row["scur"]
        report "#{name} Current Queue" => row["qcur"] unless row["qcur"].nil?
        report "#{name} Requests / second" => row["rate"] unless row["rate"].nil?
      end
    end
  end
end
