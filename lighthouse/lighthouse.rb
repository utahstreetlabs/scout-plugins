require 'rubygems'
require 'lighthouse-api'

class LighthouseStats < Scout::Plugin
#  needs 'activeresource'

  def build_report
    Lighthouse.account = option('account')
    Lighthouse.token = option('api_token')

    page = 1
    num_tickets = 0
    more_tickets = true

    #
    # lighthouse will only return 30 tickets at a time, so we have to page through the results
    #
    while more_tickets do
      tickets = Lighthouse::Ticket.find(:all, :params => { :page => page, :project_id => option('project_id'), :q => "state:open"})

      if tickets.size > 0
        num_tickets += tickets.size
        page += 1
      else
        more_tickets = false
      end
    end

    report(:open_tickets => num_tickets)

  rescue
    error( :subject => "Error talking to lighthouse or parsing xml", :body => $!.message)
  end

end