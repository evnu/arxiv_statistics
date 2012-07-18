#!/usr/bin/ruby
#
# Retrieve statistics for a given category using OAI.
#

require 'oai'
require 'ripl'

client = OAI::Client.new 'http://export.arxiv.org/oai2'

resumption_token = :first_run

@all_records = []
@file = "dump.bin"

def dump_data
    puts "Dumping to #{@file}"
    serialized = Marshal.dump(@all_records)
    File.open(@file, "w+"){|f| f.write(serialized)}
end

# dump on Ctrl+C
trap("INT"){dump_data() and exit}

begin
    # construct a query
    # if this is the first round, use a date
    # if this isn't the first round, set the resumption_token
    request = if resumption_token and resumption_token != :first_run
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
        if response.resumption_token.nil?
            Ripl.start :binding => binding
            exit
        end
        resumption_token = response.resumption_token
        puts "#{resumption_token}"

        puts "Filtering record information"
        current = response.map do |record|
            meta = record.metadata.children[1]

            id = meta.elements["id"].text
            versions = meta.children.map do |child|
                next if child.class != REXML::Element
                {
                    :version => child.attributes["version"],
                    :date => child.children[0].text,
                    :size => child.children[1].text
                } if child.name == "version"
            end.compact!

            {id => versions}
        end

        @all_records << current
    end
end while resumption_token

dump_data

puts "Finished retrieving data"
Ripl.start :binding => binding
