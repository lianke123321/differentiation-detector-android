#!/bin/bash

directoryname=pcaps
echo "Reading pcap files from" $directoryname

# gets a file consisting entirely of IP addresses and timestamps
# does not contain private addresses
for file in $directoryname/*;
do
name=$(echo $file | awk -F '.' '{print $1}' | awk -F '/' '{print $2}')
echo "Reading this specific file: " $name
tcpdump -ttttnr $file | awk -F 'Flags' '{print $1}' | awk -F '> ' '{print $1}' | awk -F 'IP ' '{print $2 "." $1}'  | awk -F '.' '{print $1"."$2"."$3"."$4 "\t" $6"."$7}'| sort -k1,1 -k2n,2 | grep -v "^10\." | egrep "[0-9]+-[0-9]+-[0-9]+" >> ip_ts_$name.txt ;

 done 

