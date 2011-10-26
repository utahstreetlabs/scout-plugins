# =================================================================================
# rabbitmq_overall
#
# Created by Erik Wickstrom on 2011-10-14.
# =================================================================================

class RabbitmqOverall < Scout::Plugin
  needs 'rubygems'
  needs 'json'
  needs 'net/http'

  OPTIONS=<<-EOS
    management_url:
        default: http://localhost:55672
        notes: The base URL of your RabbitMQ Management server.
    username:
        default: guest
    password:
        default: guest
    queue:
        notes: The name of the queue to collect detailed metrics for
    vhost:
        notes: The virtual host containing the queue.
    frequency:
        default: minute
        notes: The frequency at which sample rates should be calculated (ie "7 failures per minute").  Valid options are minute and second.
  EOS

  def build_report
    if option(:frequency) == "second"
        frequency = :second
    else
        frequency = :minute
    end

    if option(:queue).nil?
        error("Plugin not configured.")
        return
    end

    queue = get_queue(option(:vhost), option(:queue))

    if queue["durable"]
        durable = 1
    else
        durable = 0
    end

    report(:messages => queue["messages"],
           :messages_unacknowledged => queue["messages_unacknowledged"],
           :memory => queue["memory"].to_f / (1024 * 1024),
           :pending_acks => queue["backing_queue_status"]["pending_acks"],
           :consumers => queue["consumers"],
           :durable => durable,
           :messages_ready => queue["messages_ready"])

    #counter(:failures, results["FAILURE"], :per => frequency)
  end


  def get_queue(vhost, queue)
     url = "#{option('management_url').to_s.strip}/api/queues/#{vhost}/#{queue}/""
     result = query_api(url)
  end


  def get_nodes
     url = "#{option('management_url').to_s.strip}/api/nodes/"
     result = query_api(url)
  end

  def get_bindings
     url = "#{option('management_url').to_s.strip}/api/bindings/"
     result = query_api(url)
  end

  def get_connections
     url = "#{option('management_url').to_s.strip}/api/connections/"
     result = query_api(url)
  end

  def get_exchanges
     url = "#{option('management_url').to_s.strip}/api/exchanges/"
     result = query_api(url)
  end

  def get_queues
     url = "#{option('management_url').to_s.strip}/api/queues/"
     result = query_api(url)
  end

  def get_overview
     url = "#{option('management_url').to_s.strip}/api/overview/"
     result = query_api(url)
  end

  def query_api(url)
     parsed = URI.parse(url)
     http = Net::HTTP.new(parsed.host, parsed.port)
     req = Net::HTTP::Get.new(parsed.path)
     req.basic_auth option(:username), option(:password)
     response = http.request(req)
     data = response.body
  
     # we convert the returned JSON data to native Ruby
     # data structure - a hash
     result = JSON.parse(data)
  
     # if the hash has 'Error' as a key, we raise an error
     #if result.has_key? 'Error'
     #   raise "web service error"
     #end
     return result
  end
end
