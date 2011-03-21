class FpmStatus < Scout::Plugin
  needs 'open-uri', 'json'

  OPTIONS=<<-EOS
  url:
    name: FPM Status Url
    default: "http://localhost/status?json"
  EOS

  def build_report
    url = option(:url) || 'http://localhost/status?json'
    open(url) do |p|
      content = p.read
      stats = JSON.parse(content)
      report({:idle_processes => stats["idle processes"].to_i,
            :active_processes => stats["active processes"].to_i,
            :total_processes => stats["total processes"].to_i})
    end
  end
end