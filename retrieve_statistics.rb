#!/usr/bin/ruby
#
# Retrieve statistics for a given category using OAI.
#

require 'oai'
require 'ripl'

client = OAI::Client.new 'http://export.arxiv.org/oai2'

resumption_token = nil

all_responses = []

begin
    # construct a query
    # if this is the first round, use a date
    # if this isn't the first round, set the resumption_token
    request = if resumption_token
                  {:resumption_token => resumption_token}
              else
                  {:from => "1991-01-01",
                   :metadataPrefix => "arXivRaw",
                   :set => 'cs',
                  }
              end

    response = client.list_records(request)

    # if the resumption token is nil, we have to check if the response was declined for
    # FlowControl reasons. Check the result document and retry after some seconds
    if response.doc.elements["//h1"]
        wait = response.doc.elements["//h1"].text
        # parse the result query
        seconds = wait.match(/ \d+ /)[0].rstrip!
        puts "Forced to sleep #{seconds} s"
        sleep(Integer(seconds))
    else
        resumption_token = response.resumption_token
        puts "#{resumption_token}"
        all_responses << response
    end
end while resumption_token

Ripl.start :binding => binding
