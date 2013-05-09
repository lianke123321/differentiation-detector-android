#/usr/bin/ruby
#
# Maps the pcapbyresults.txt file (tabulated PII violations by file/timestamp) to an app (apktimestamps.txt)
# usage: ./map_results_to_app.rb apktimestamps.txt pcapcbypcapresults.txt
require 'time'

if(ARGV.length != 2) then
  $stderr.puts "usage: ./map_results_to_app.rb apktimestamps.txt pcapcbypcapresults.txt"
  exit 1
end

app_to_counts = {}
timestamp_to_app = {}
sorted_timestamps = []

apktsfile = File.open(ARGV[0])
apktsfile.each do |line|
  vals = line.chomp.split(" : ")
  appname = vals[0]
  timestamp = vals[1]
  timestamp_ts = Time.parse(timestamp)
  timestamp_to_app[timestamp_ts] = appname
  sorted_timestamps << timestamp_ts
end
apktsfile.close

##Index in to this array to find when I ran
sorted_timestamps.sort!

pcapcounts = File.open(ARGV[1])
curts = nil
curapp = nil
pcapcounts.each do |line|
  if(line =~ /tcpdump/) then #this is the filename, grep the epoch time 
    epoch_time = line[/[0-9]{10}/].to_i
    
    timestamp = Time.at(epoch_time)
    #$stderr.puts("current time #{timestamp}")

    i = sorted_timestamps.size - 1
    while(i >=0) do
      break if(sorted_timestamps[i] < timestamp)
      i -= 1
    end
 
    if(i < 0) then
      $stderr.puts("unable to map #{line} to an app :(; mapping to first app...")
      i = 0
    end
    curts = sorted_timestamps[i]
    curapp = timestamp_to_app[curts]
    #$stderr.puts("mapping #{line} to #{curapp}")
  elsif(line =~ /[0-9]:[0-9]/) #this is the timestampline, skip because it doesn't go in to seconds
    #noop
  else #this is a count to store
      vals = line.chomp.split(":")
      label = vals[0]
      count = vals[1].to_i
      app_to_counts[curapp] = {} if(app_to_counts[curapp].nil?)
      app_to_counts[curapp][label] = 0 if(app_to_counts[curapp][label].nil?)
      app_to_counts[curapp][label] += count
  end
end

app_to_counts.each do |app, hash|
  print app
  hash.each do |label, count|
    print " #{label}:#{count}"
  end
  print "\n"
end
