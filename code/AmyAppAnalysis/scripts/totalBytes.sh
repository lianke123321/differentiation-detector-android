#!/bin/sh
#Takes in the directory of the files, takes names out output files
#output file sent is for number of bytes sent from phone
#output file received is for number of bytes received from phone
#IP is the IP of the phone
# amy: 10.11.4.11, test1: 10.11.4.21, test2: 10.11.4.22, test3: 10.11.4.23
directory=$1
sent=$2
received=$3
IP=$4

for file in $directory/*;
do
echo -n $file >> $sent
echo -n $file >> $received
tcpdump -r $file src $IP  | egrep -io 'length [0-9]+' | cut -d " " -f 2 | awk '{ sum += $1 } END { print sum }' >> $sent
tcpdump -r $file dst $IP | egrep -io 'length [0-9]+' | cut -d " " -f 2 | awk '{ sum += $1 } END { print sum }' >> $received
done;
