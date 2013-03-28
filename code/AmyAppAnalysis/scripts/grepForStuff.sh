#!/bin/bash

filename="$1"

tcpdump -Ar $filename| grep -v 'TCP' | grep -v 'HTTP' | grep -v 'seq' >> httpdata.txt

echo "\nLooking for lat=, latitude=\n"
egrep -io "(\")?lat(\")?([=:])+\"?[0-9]+(\.[0-9]+)?" httpdata.txt | sort | uniq -c
egrep -io "(\")?latitude(\")?([=:])+\"?[0-9]+(\.[0-9]+)?" httpdata.txt | sort | uniq -c

echo "\nLooking for lon=, long=, longitude=\n"
egrep -io "(\")?lon(\")?([:=])+(\"?)[0-9]+(\.[0-9]+)?" httpdata.txt | sort | uniq -c
egrep -io "(\")?long(\")?([=:])+(\")?[0-9]+(\.[0-9]+)?" httpdata.txt | sort | uniq -c
egrep -io "(\")?longitude(\")?([=:])+\"?[0-9]+(\.[0-9]+)?" httpdata.txt | sort | uniq -c

echo "\nLooking for pw=, pwd=, password=, user=\n"
egrep -io "(\")?pw(\")?([=:])+(\"?)....." httpdata.txt | sort | uniq -c
egrep -io "(\")?pwd(\")?([:=])+(\"?)...." httpdata.txt | sort | uniq -c
egrep -io "(\")?password(\")?([:=])+(\"?)...." httpdata.txt | sort | uniq -c
egrep -io "(\")?user(\")?([:=])+(\"?)...." httpdata.txt | sort | uniq -c

echo "\nLooking for IMEI= \n"
egrep -io "(\")?IMEI(\")?([:=])+(\"?)...." httpdata.txt | sort | uniq -c
egrep -io "(\")?udid(\")?([:=])+(\"?)[0-9]+" httpdata.txt | sort | uniq -c
egrep -io "(\")?uuid(\")?([:=])+(\"?)[0-9]+" httpdata.txt | sort | uniq -c
egrep -io "(\")?-Id(\")?([:=])+(\"?)[0-9]+" httpdata.txt | sort | uniq -c
#phone-specific searches
grep -i "9419f52ee69ffcba" httpdata.txt | sort | uniq -c
grep -i "355031040753366" httpdata.txt | sort | uniq -c
 
eche}} "\nLooking for phone number, also phone=, number= \n"
grep -io '......([:=])+\(([0-9]\{3\})\|[0-9]\{3\}\)[ -]\?[0-9]\{3\}[ -]\?[0-9]\{4\}' httpdata.txt | grep -v 'ecr' | grep -v 'seq' | grep -v 'val' | grep -v 'ack' | sort | uniq -c
egrep -io "(\")?number(\")?([:=])+(\"?).........." httpdata.txt | sort | uniq -c
egrep -io "(\")?phone(\")?([:=])+(\"?)........." httpdata.txt | sort | uniq -c
#grep -i -e -o "lat=+\d+\}" httpdata.txt | sort | uniq -c

echo "\nLooking for credit card numbers\n"
egrep -io '4[0-9]{12}(?:[0-9]{3})?' httpdata.txt | sort  | uniq -c #Visa
egrep -io '5[1-5][0-9]{14}' httpdata.txt | sort | uniq -c #MasterCard
egrep -io '[47][0-9]{13}' httpdata.txt | sort | uniq -c #AmEx
egrep -io '3(?:0[0-5]|[68][0-9])[0-9]{11}' httpdata.txt | sort | uniq -c #DinersClub
egrep -io '6(?:011|5[0-9]{2})[0-9]{12}' httpdata.txt | sort | uniq -c #Discover
egrep -io '(?:2131|1800|35\d{3})\d{11}' httpdata.txt | sort | uniq -c #JCB

echo "\nLooking for emails\n"
egrep -io '[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,4}' httpdata.txt | grep -v 'png' | grep -v 'jpg' | grep -v 'jpeg' | grep -v 'gif' | sort | uniq -c
#tcpdump -Ar $filename | grep -i latitude
#tcpdump -Ar $filename | grep -i long=
#tcpdump -Ar $filename | grep -i longitude
#tcpdump -Ar $filename | grep -i password

#tcpdump -Ar $filename | grep -i IMEI
#tcpdump -Ar $filename | grep -i pwd
