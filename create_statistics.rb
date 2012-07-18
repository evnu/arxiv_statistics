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

# calculate for each retracted record how long it lasted until it was retracted
retraction_time = @normalized_records.map do |record|
    # calculate the timespan until it was retracted the first time
    start = nil
    last = nil
    abort_loop = false

    record.values.flatten(1).each do |version|
        next if abort_loop

        date = Date.parse(version[:date])
        if version[:version] == "v1"
            start = date
        elsif version[:size].match(/^0kb/)
            # if the last one is zero as well, than count this one as retracted
            if record.values.flatten(1)[-1][:size].match(/^0kb/)
                last = date
                abort_loop = true
            end
        end
    end

    (last - start).numerator if last
end.compact!

# create histogram from retraction_time array
retraction_time_hist = Hash.new(0)
retraction_time.each{|r| retraction_time_hist[r] += 1}

# calculate the time until the first update
update_time = @normalized_records.map do |record|
    start = nil
    update = nil
    abort_loop = false

    record.values.flatten(1).each do |version|
        next if abort_loop

        date = Date.parse(version[:date])
        if version[:version] == "v1"
            start = date
        elsif version[:version] == "v2"
            update = date
            abort_loop = true
        end
    end

    (update - start).numerator if update
end.compact!

update_time_hist = Hash.new(0)
update_time.each{|r| update_time_hist[r] += 1}

# create a plot for the results
puts "plotting absolute numbers"
Gnuplot.open do |gp|
    Gnuplot::Plot.new(gp) do |plot|
        plot.xrange("[#{@first_year}:#{@last_year}]")
        plot.title("arXiv.org changes from #{@first_year} to #{@current_year}")
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
        plot.title("arXiv.org changes from #{@first_year} to #{@current_year}")
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

puts "plotting days until retraction"
Gnuplot.open do |gp|
    Gnuplot::Plot.new(gp) do |plot|
        plot.xrange("[0:#{retraction_time.max}]")
        plot.title("arXiv.org days until retraction")
        plot.ylabel("retractions")
        plot.xlabel("after days")
        plot.output("retraction_time.png")
        plot.terminal('png')

        plot.data << Gnuplot::DataSet.new([retraction_time_hist.keys, retraction_time_hist.values]) { |ds|
            ds.with = "impulses"
            ds.title = "retractions"
            ds.linewidth = 1
        }
    end
end


puts "plotting days until update"
Gnuplot.open do |gp|
    Gnuplot::Plot.new(gp) do |plot|
        plot.xrange("[0:#{update_time.max}]")
        plot.title("arXiv.org days until update")
        plot.ylabel("updates")
        plot.xlabel("after days")
        plot.output("update_time.png")
        plot.terminal('png')

        plot.data << Gnuplot::DataSet.new([update_time_hist.keys, update_time_hist.values]) { |ds|
            ds.with = "impulses"
            ds.title = "updates"
            ds.linewidth = 1
        }
    end
end
