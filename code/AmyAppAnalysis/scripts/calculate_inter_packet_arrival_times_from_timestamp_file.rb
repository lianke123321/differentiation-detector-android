#!/usr/bin/ruby
require 'date'

# Takes one of Amy's timestamp files and calculates the 
# inter-packet arrival times. Prints a set of summary statistics 
# to stderr.

input = ARGV[0]

deltas = []
timestamps = []

f = File.open(input)
f.each{|line|
    ts = line.gsub(/\A[^ ]*/, "")
#    puts ts
    ts = DateTime.parse(ts)
    millis = ts.strftime('%s%L').to_i
    timestamps << millis
}
f.close

timestamps.sort!

last = nil
timestamps.each{|ts|
    if(last != nil) then
        puts ts - last
        deltas << ts - last
    end
    last = ts
}


x = deltas

$stderr.puts "MAX: #{x.max}"
$stderr.puts "MIN: #{x.min}"
$stderr.puts "MED: #{x.sort[x.size / 2]}"
avg = x.inject{|a,b| a + b} / x.size 
$stderr.puts "AVG: #{avg}"
sum = x.inject{|sum,a| sum + a }
$stderr.puts "SUM: #{sum}"

stddev = 0
x.each{|val| stddev += (val - avg) ** 2}
stddev = stddev / x.size
stddev = Math.sqrt(stddev)
$stderr.puts "STD. DEV: #{stddev}"
