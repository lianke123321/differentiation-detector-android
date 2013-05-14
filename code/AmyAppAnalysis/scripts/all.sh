#!/bin/bash

directoryname="$1"
echo "Reading pcap files from" $directoryname

rm -r $1/ipts
rm -r $1/namestotimestamps
rm -r $1/output

mkdir $1/ipts
mkdir $1/namestotimestamps
mkdir $1/output
for file in $directoryname/*.pcap;
do
# This translates every IP address to a name based on the OrgName in whois. Outputs a file in format: <IP> <NAME>
tcpdump -tnr $file  | awk -F '.' '{print $1"."$2"."$3"."$4}' | sort | uniq | awk -F ' ' '{print $2}' | sort | uniq | while read line; do echo "$line	$(whois $line | grep OrgName | sed 's/   */	/g' | cut -f2)"; done >> $1/ip_to_identity.txt

# Gets and formats the name of the file
name=$(echo $file | awk -F '.' '{print $1}' | awk -F '/' '{print $2}')

# Puts out a file in format: <IP> <timestamp>, e.g. 107.21.16.113	2012-11-25 14:07:14.104241 
tcpdump -ttttnr $file | awk -F 'Flags' '{print $1}' | awk -F '> ' '{print $1}' | awk -F 'IP ' '{print $2 "." $1}'  | awk -F '.' '{print $1"."$2"."$3"."$4 "\t" $6"."$7}'| sort -k1,1 -k2n,2 | grep -v "^10\." | egrep "[0-9]+-[0-9]+-[0-9]+" >> $1/ipts/ip_ts_$name.txt 

# Outputs file namestotimestamps.txt in format: <Name> <Timestamps>
python scripts/iptoname.py $1/ipts/ip_ts_$name.txt $1/ip_to_identity.txt 
# Sorts the file by timestamps
cat $1/namestotimestamps.txt | sort -k3,3 -t '"' -s >> $1/namestotimestamps/sorted_namestotimestamps.txt

# Splits each timestamps into separate days
python scripts/split.py $1/namestotimestamps/sorted_namestotimestamps.txt

done;
