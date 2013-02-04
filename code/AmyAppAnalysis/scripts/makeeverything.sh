#!/bin/bash

directoryname="$1"
echo "Reading pcap files from" $directoryname

mkdir ipts
mkdir namestotimestamps
for file in $directoryname/*;
do
name=$(echo $file | awk -F '.' '{print $1}' | awk -F '/' '{print $2}')
echo "Reading this specific file: " $name
tcpdump -ttttnr $file | awk -F 'Flags' '{print $1}' | awk -F '> ' '{print $1}' | awk -F 'IP ' '{print $2 "." $1}'  | awk -F '.' '{print $1"."$2"."$3"."$4 "\t" $6"."$7}'| sort -k1,1 -k2n,2 | grep -v "^10\." | egrep "[0-9]+-[0-9]+-[0-9]+" >> ipts/ip_ts_$name.txt 

python scripts/iptoname.py ipts/ip_ts_$name.txt ip_to_identity.txt 
cat namestotimestamps.txt | sort -k 2 >> namestotimestamps.txt 
mv namestotimestamps.txt namestotimestamps/names_ts_$name.txt;

done; 

#./ip_to_identity.sh ip_time_stamps.txt.tst >> ip_to_identity.txt

#cat namestotimestamps.txt | sort -k 2 >> datesorted_ip_timestamps.txt

#python split.py datesorted_ip_timestamps.txt

#// for file in output/*; do python iptoname.py $file ip_to_identity.txt ; done
#cat iptimestamps.txt.nobugs.noprivate | awk -F ' ' '{print $1 "\t" $2 "\t" $3}' | sort -k2,2
