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
tcpdump -tnr $file  | awk -F '.' '{print $1"."$2"."$3"."$4}' | sort | uniq | awk -F ' ' '{print $2}' | sort | uniq | while read line; do echo "$line	$(whois $line | grep OrgName | sed 's/   */	/g' | cut -f2)"; done >> $1/ip_to_identity.txt

name=$(echo $file | awk -F '.' '{print $1}' | awk -F '/' '{print $2}')

tcpdump -ttttnr $file | awk -F 'Flags' '{print $1}' | awk -F '> ' '{print $1}' | awk -F 'IP ' '{print $2 "." $1}'  | awk -F '.' '{print $1"."$2"."$3"."$4 "\t" $6"."$7}'| sort -k1,1 -k2n,2 | grep -v "^10\." | egrep "[0-9]+-[0-9]+-[0-9]+" >> $1/ipts/ip_ts_$name.txt 

python scripts/iptoname.py $1/ipts/ip_ts_$name.txt $1/ip_to_identity.txt 
cat $1/namestotimestamps.txt | sort -k3,3 -t '"' -s >> $1/namestotimestamps/sorted_namestotimestamps.txt
python scripts/split.py $1/namestotimestamps/sorted_namestotimestamps.txt

#for outfile in $1/output/*.txt;
#do
#cat $outfile | sort -c >> $outfile.sorted; done;

done;
