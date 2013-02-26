#!/bin/bash

filename="$1"

httpdata=$(tcpdump -Ar $filename| grep -v 'TCP' | grep -v 'HTTP')

echo $httpdata >> httpdata.txt

echo "\nLooking for lat=, latitude=\n"
grep -io "lat=.[0-9]\{0,5\}.[0-9]\{0,5\}" httpdata.txt
grep -io "latitude=.[0-9]\{0,5\}.[0-9]\{0,5\}" httpdata.txt

echo "\nLooking for lon=, long=, longitude=\n"
grep -io "lon=.[0-9]\{0,5\}.[0-9]\{0,5\}" httpdata.txt
grep -io "long=.[0-9]\{0,5\}.[0-9]\{0,5\}" httpdata.txt
grep -io "longitude=.[0-9]\{0,5\}.[0-9]\{0,5\}" httpdata.txt

echo "\nLooking for pw=, pwd=, password=, user=\n"
grep -io "pw=." httpdata.txt
grep -io "pwd=." httpdata.txt
grep -io "password=." httpdata.txt
grep -io "user=." httpdata.txt

echo "\nLooking for IMEI= \n"
grep -io "IMEI=...." httpdata.txt

echo "\nLooking for phone number, also phone=, number= \n"
grep -io '......\(([0-9]\{3\})\|[0-9]\{3\}\)[ -]\?[0-9]\{3\}[ -]\?[0-9]\{4\}' httpdata.txt
grep -io "number=.........." httpdata.txt
grep -io "phone=........." httpdata.txt
#grep -i -e -o "lat=\d+\}" httpdata.txt

echo "\nLooking for credit card numbers\n"
egrep -io '4[0-9]{12}(?:[0-9]{3})?' httpdata.txt #Visa
egrep -io '5[1-5][0-9]{14}' httpdata.txt #MasterCard
egrep -io '[47][0-9]{13}' httpdata.txt #AmEx
egrep -io '3(?:0[0-5]|[68][0-9])[0-9]{11}' httpdata.txt #DinersClub
egrep -io '6(?:011|5[0-9]{2})[0-9]{12}' httpdata.txt #Discover
egrep -io '(?:2131|1800|35\d{3})\d{11}' httpdata.txt #JCB

echo "\nLooking for emails\n"
egrep -io '[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,4}' httpdata.txt
#tcpdump -Ar $filename | grep -i latitude
#tcpdump -Ar $filename | grep -i long=
#tcpdump -Ar $filename | grep -i longitude
#tcpdump -Ar $filename | grep -i password

#tcpdump -Ar $filename | grep -i IMEI
#tcpdump -Ar $filename | grep -i pwd
