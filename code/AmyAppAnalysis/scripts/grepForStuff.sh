#!/bin/bash

filename="$1"

httpdata=$(tcpdump -Ar $filename)

echo $httpdata >> httpdata.txt

echo "\nLooking for lat=, latitude=\n"
grep -o "lat=.[0-9]\{0,5\}.[0-9]\{0,5\}" httpdata.txt
grep -o "latitude=.[0-9]\{0,5\}.[0-9]\{0,5\}" httpdata.txt


echo "\nLooking for lon=, long=, longitude=\n"
grep -o "lon=.[0-9]\{0,5\}.[0-9]\{0,5\}" httpdata.txt
grep -o "long=.[0-9]\{0,5\}.[0-9]\{0,5\}" httpdata.txt
grep -o "longitude=.[0-9]\{0,5\}.[0-9]\{0,5\}" httpdata.txt

echo "\nLooking for pw=, pwd=, password=, user=\n"
grep -o "pw=." httpdata.txt
grep -o "pwd=." httpdata.txt
grep -o "password=." httpdata.txt
grep -o "user=." httpdata.txt

echo "\nLooking for IMEI= \n"
grep -o "IMEI=...." httpdata.txt

echo "\nLooking for phone number, also phone=, number= \n"
grep -o '......\(([0-9]\{3\})\|[0-9]\{3\}\)[ -]\?[0-9]\{3\}[ -]\?[0-9]\{4\}' httpdata.txt
grep -o "number=.........." httpdata.txt
grep -o "phone=........." httpdata.txt
#grep -i -e -o "lat=\d+\}" httpdata.txt

#tcpdump -Ar $filename | grep -i latitude
#tcpdump -Ar $filename | grep -i long=
#tcpdump -Ar $filename | grep -i longitude
#tcpdump -Ar $filename | grep -i password

#tcpdump -Ar $filename | grep -i IMEI
#tcpdump -Ar $filename | grep -i pwd
