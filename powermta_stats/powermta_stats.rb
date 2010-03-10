class PowermtaStats < Scout::Plugin

  needs 'nokogiri','open-uri'

  OPTIONS=<<-EOS
    uri:
    name: URI
    notes: URI of the PowerMTA Web Interface url
    default: http://127.0.0.1:8080/
  EOS

  def build_report
    uri = option(:uri) || "http://127.0.0.1:8080/"
    status = Nokogiri::XML(open(uri+'status?format=xml'))
    report({
      "Out: Recipients/min" => status.xpath('//rsp/data/status/traffic/lastMin/out/rcp').children.first.content,
      "Out: Messages/min" => status.xpath('//rsp/data/status/traffic/lastMin/out/msg').children.first.content,
      "Out: KB/min" => status.xpath('//rsp/data/status/traffic/lastMin/out/kb').children.first.content,
      "Out: SMTP Connections/min" => status.xpath('//rsp/data/status/conn/smtpOut/cur').children.first.content,
      "In: Recipients/min" => status.xpath('//rsp/data/status/traffic/lastMin/in/rcp').children.first.content,
      "In: Messages/min" => status.xpath('//rsp/data/status/traffic/lastMin/in/msg').children.first.content,
      "In: KB/min" => status.xpath('//rsp/data/status/traffic/lastMin/in/kb').children.first.content,
      "In: SMTP Connections/min" => status.xpath('//rsp/data/status/conn/smtpIn/cur').children.first.content,
      "Queued Recpipents" => status.xpath('//rsp/data/status/queue/smtp/rcp').children.first.content,
      "Queued Domains" => status.xpath('//rsp/data/status/queue/smtp/dom').children.first.content,
      "Queued KB" => status.xpath('//rsp/data/status/queue/smtp/kb').children.first.content,
      "Spool Files" => status.xpath('//rsp/data/status/spool/files/total').children.first.content,
      "Spool Initialization" => status.xpath('//rsp/data/status/spool/initPct').children.first.content
    })
    vmtas = Nokogiri::XML(open(uri+'vmtas?format=xml'))
    vmtas.xpath('//rsp/data').children.each do |vmta|
      report(('VMTA Queue Size: ' + vmta.xpath('name').first.content) => vmta.xpath('rcp').first.content)
    end
  end
end
