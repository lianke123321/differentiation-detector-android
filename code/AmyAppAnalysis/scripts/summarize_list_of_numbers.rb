#!/usr/bin/ruby

x = []

if(ARGV.size == 0) then
    input = STDIN
else
    input = File.open(ARGV[0])
end

input.each{|line| x << line.chomp.to_f}

puts "MAX: #{x.max}"
puts "MIN: #{x.min}"
puts "MED: #{x.sort[x.size / 2]}"
avg = x.inject{|a,b| a + b} / x.size 
puts "AVG: #{avg}"
sum = x.inject{|sum,a| sum + a }
puts "SUM: #{sum}"

stddev = 0
x.each{|val| stddev += (val - avg) ** 2}
stddev = stddev / x.size
stddev = Math.sqrt(stddev)
puts "STD. DEV: #{stddev}"
