#!/bin/bash

filename="$1"

httpdata=$(tcpdump -Ar $filename)

echo $httpdata >> httpdata.txt

echo "\nLooking for lat=, latitude=\n"
grep -io "lat=.[0-9]\{0,5\}.[0-9]\{0,5\}" httpdata.txt
grep -io "latitude=.[0-9]\{0,5\}.[0-9]\{0,5\}" httpdata.txt


echo "\nLooking for lon=, long=, longitude=\n"
grep -io "lon=.[0-9]\{0,5\}.[0-9]\{0,5\}" httpdata.txt
grep -io "long=.[0-9]\{0,5\}.[0-9]\{0,5\}" httpdata.txt
grep -io "longitude=.[0-9]\{0,5\}.[0-9]\{0,5\}" httpdata.txt

echo "\nLooking for pw=, pwd=, password=, user=\n"
egrep -io "pw=[^ ]+" httpdata.txt
egrep -io "pwd=[^ ]+" httpdata.txt
egrep -io "password=[^ ]+" httpdata.txt
egrep -io "user=[^ ]+" httpdata.txt

##TODO: add fake password/fake account, and then grep for that pass

echo "\nLooking for email addresses"
egrep -io "[^ ]+@([a-z]+\.)+(((com)|(org))|((edu)|(net)))" httpdata.txt

echo "\nLooking for IMEI= \n"
grep -io "IMEI=[0-9]+" httpdata.txt

echo "\nLooking for phone number, also phone=, number= \n"
grep -o '......\(([0-9]\{3\})\|[0-9]\{3\}\)[ -]\?[0-9]\{3\}[ -]\?[0-9]\{4\}' httpdata.txt
grep -io "number=.........." httpdata.txt
grep -io "phone=........." httpdata.txt
#grep -i -e -o "lat=\d+\}" httpdata.txt

echo "\nLooking for credit card numbers"

#tcpdump -Ar $filename | grep -i latitude
#tcpdump -Ar $filename | grep -i long=
#tcpdump -Ar $filename | grep -i longitude
#tcpdump -Ar $filename | grep -i password

#tcpdump -Ar $filename | grep -i IMEI
#tcpdump -Ar $filename | grep -i pwd
