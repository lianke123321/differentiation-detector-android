#!/bin/sh
# Outputs a file that is formatted like
# filename
# organization1 
# organization2
# ...
# organizationN
# ip_to_identity.txt must be cleared beforehand, or the right file to add onto.

directoryname=$1
for file in $directoryname/*.pcap;
do
echo $file >> ip_to_identity.txt 
tcpdump -tnr $file  | awk -F '.' '{print $1"."$2"."$3"."$4}' | sort | uniq | awk -F ' ' '{print $2}' | sort | uniq | while read line; do echo "$line	$(whois $line | grep OrgName | sed 's/   */	/g' | cut -f2)"; done >> ip_to_identity.txt

done;
