#!/usr/bin/ruby
#
# Load an arXiv.org dump produced by retrieve_dump.rb and
# output some statistics
#
require 'date'
require 'pp'

@file = "dump.bin"

def record_retracted record
end

def select_retracted_entries records
    records.select do |record|
        record.values.flatten!(1).map do |version|
            true if version[:size] == "0kb"
        end.compact!.to_set.first
    end
end

# deserialize dump
@all_records = Marshal.load(File.open(@file).readlines.join(""))
@normalized_records = @all_records.flatten(1)

# for each year: calculate the number of submitted/changed/retracted entries

years = (1990..2012).to_a
per_year_stats = (1990..2012).map{Hash.new(0)}
@statistics = Hash[*years.zip(per_year_stats).flatten]

@normalized_records.each do |record|
    record.values.flatten(1).each do |version|
        date = Date.parse(version[:date])
        size = version[:size]
        version = version[:version]
        change_action = if version == "v1"
                            :submitted
                        elsif size != "0kb"
                            :updated
                        else
                            :retracted
                        end

        @statistics[date.year.to_i][change_action] += 1
    end
end

puts (PP.pp(@statistics))
