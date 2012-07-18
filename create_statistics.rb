#!/usr/bin/ruby
#
# Load an arXiv.org dump produced by retrieve_dump.rb and
# output some statistics
#
require 'date'
require 'pp'
require 'gnuplot'
require 'optiflag'
require 'set'

module CLIArgs extend OptiFlagSet
    flag "dumpfile"
    optional_flag "first_year"
    optional_flag "last_year"

    usage_flag "help"

    and_process!
end

@file = ARGV.flags.dumpfile
@first_year = (ARGV.flags.first_year || 1993).to_i
@last_year  = (ARGV.flags.last_year   || 2012).to_i

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

start_year = 1990
current_year = DateTime.now.year

@years = (start_year..current_year).to_a
per_year_stats = (start_year..current_year).map{Hash.new(0)}
@statistics = Hash[*@years.zip(per_year_stats).flatten]


@normalized_records.each do |record|
    record.values.flatten(1).each do |version|
        date = Date.parse(version[:date])
        size = version[:size]
        version = version[:version]

        change_action = if version == "v1"
                            :submitted
                        elsif size.match(/^0kb/)
                            :retracted
                        else
                            :updated
                        end

        @statistics[date.year.to_i][change_action] += 1
    end
end

# output a table of absolute numbers
puts "year\tsubmissions\tupdates\tretractions\tratio submissions vs. retractions"
(@first_year..@last_year).each do |year|
    stats       = @statistics[year]
    submissions = stats[:submitted]
    updates     = stats[:updated]
    retractions = stats[:retracted]
    ratio       = retractions / submissions.to_f * 100
    printf "#{year}\t#{submissions}\t#{updates}\t#{retractions}\t#{ratio}\n"
end

# create a plot for the results
puts "plotting absolute numbers"
Gnuplot.open do |gp|
    Gnuplot::Plot.new(gp) do |plot|
        plot.xrange("[#{@first_year}:#{@last_year}]")
        plot.title("arXiv.org changes from 1990 to current year")
        plot.ylabel("actions")
        plot.xlabel("year")
        plot.output("absolute_numbers.png")
        plot.terminal('png')

        plot.data = [:submitted, :updated, :retracted].map do |action|
            data = [@years,@years.map do |year|
                @statistics[year][action]
            end]
            Gnuplot::DataSet.new(data) { |ds|
                ds.with = "lines"
                ds.title = "#{action}"
                ds.linewidth = 4
            }
        end
    end
end

puts "plotting ratio"
Gnuplot.open do |gp|
    Gnuplot::Plot.new(gp) do |plot|
        plot.xrange("[#{@first_year}:#{@last_year}]")
        plot.title("arXiv.org changes from 1990 to current year")
        plot.ylabel("actions")
        plot.xlabel("year")
        plot.output("ratio.png")
        plot.terminal('png')

        data = [@years,@years.map do |year|
            stats       = @statistics[year]
            submissions = stats[:submitted]
            retractions = stats[:retracted]
            ratio       = retractions / submissions.to_f * 100
        end]
        plot.data << Gnuplot::DataSet.new(data) { |ds|
            ds.with = "lines"
            ds.title = "ratio"
            ds.linewidth = 4
        }
    end
end
