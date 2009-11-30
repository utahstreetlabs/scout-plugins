%w( fastercsv open-uri ).each { |f| require f }

class HaproxyStats < Scout::Plugin
  def build_report
    FasterCSV.parse(open(option(:uri)), :headers => true) do |row|
      name = row["# pxname"] + ' ' + row["svname"].downcase
      report "#{name} Current Sessions" => row["scur"]
      report "#{name} Max Sessions" => row["smax"]
      report "#{name} Session Limit" => row["slim"]
      report "#{name} Current Queue" => row["qcur"] unless row["qcur"].nil?
      report "#{name} Max Queue" => row["qmax"] unless row["qmax"].nil?
      if row['status'] == 'DOWN'
        alert("#{row['svname']} DOWN", row.to_hash.inspect) unless memory("#{row['svname']} DOWN")
        remember("#{row['svname']} DOWN" => true)
      elsif memory("#{row['svname']} DOWN")
        alert("#{row['svname']} UP", row.to_hash.inspect)
        memory.delete("#{row['svname']} DOWN")
      end
    end
  end
end
