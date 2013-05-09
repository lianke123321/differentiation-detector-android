#!/bin/bash

filename="$1"

tcpdump -Ar $filename| grep -v 'TCP' | grep -v 'HTTP' | grep -v 'seq' > httpdata.txt
echo $filename

echo "-Looking for lat=, latitude="
egrep -io "[^a-zA-Z]?lat([^a-zA-Z]|itude).*[0-9]+(\.?)[0-9]+" httpdata.txt | sort | uniq -c
#echo " Looking for lon=, long=, longitude= "
#egrep -io "[^a-zA-Z]?lon([^a-zA-Z]|g|gitude).*[0-9]+(\.?)[0-9]+"  httpdata.txt | sort | uniq -c

#echo " Looking for pw=, pwd=, password=, user= "
#egrep -io "[^a-zA-Z]?pw[^a-zA-Z]?([=:])+(\"?)....." httpdata.txt | sort | uniq -c
#egrep -io "[^a-zA-Z]?pwd[^a-zA-Z]?([:=])+(\"?)...." httpdata.txt | sort | uniq -c
#egrep -io "[^a-zA-Z]?password[^a-zA-Z]?([:=])+(\"?)...." httpdata.txt | sort | uniq -c
#egrep -io "[^a-zA-Z]?user[^a-zA-Z]?([:=])+(\"?)...." httpdata.txt | sort | uniq -c

#echo " Looking for IMEI=  "
#egrep -io "[^a-zA-Z]?IMEI[^a-zA-Z]?([:=])+(\"?)[0-9]{15,}" httpdata.txt | sort | uniq -c
#egrep -io "[^a-zA-Z]?udid[^a-zA-Z]?([:=])+(\"?)[0-9]{15,}" httpdata.txt | sort | uniq -c
#egrep -io "[^a-zA-Z]?uuid[^a-zA-Z]?([:=])+(\"?)[0-9]{15,}" httpdata.txt | sort | uniq -c
#egrep -io "[^a-zA-Z]?-Id[^a-zA-Z]?([:=])+(\"?)[0-9]{15,}" httpdata.txt | sort | uniq -c
echo "Looking for phone specific things"
#phone-specific searches
grep -i "9419f52ee69ffcba" httpdata.txt | sort | uniq -c
grep -i "355031040753366" httpdata.txt | sort | uniq -c
grep -i "testdroidmeddle" httpdata.txt | sort| uniq -c
grep -i "gameofthrones1" httpdata.txt | sort | uniq -c

#contact info (phone specific)
grep -i "amytang9" httpdata.txt | sort | uniq -c
grep -i "arya" httpdata.txt | sort | uniq -c
grep -i "stark" httpdata.txt | sort | uniq -c
grep -i "5556667777" httpdata.txt | sort | uniq -c
grep -i "(555)666-7777" httpdata.txt | sort | uniq -c
 
echo " Looking for phone number, also phone=, number=  "
#grep -io '......([:=])+\(([0-9]\{3\})\|[0-9]\{3\}\)[ -]\?[0-9]\{3\}[ -]\?[0-9]\{4\}' httpdata.txt | grep -v 'ecr' | grep -v 'seq' | grep -v 'val' | grep -v 'ack' | sort | uniq -c
egrep -io "[^a-zA-Z]?number[^a-zA-Z]?([:=])+(\"?).........." httpdata.txt | sort | uniq -c
egrep -io "[^a-zA-Z]?phone[^a-zA-Z]?([:=])+(\"?)........." httpdata.txt | sort | uniq -c
#grep -i -e -o "lat=+\d+\}" httpdata.txt | sort | uniq -c

#echo " Looking for credit card numbers "
#egrep -io '4[0-9]{12}(?:[0-9]{3})?' httpdata.txt | sort  | uniq -c #Visa
#egrep -io '5[1-5][0-9]{14}' httpdata.txt | sort | uniq -c #MasterCard
#egrep -io '[47][0-9]{13}' httpdata.txt | sort | uniq -c #AmEx
#egrep -io '3(?:0[0-5]|[68][0-9])[0-9]{11}' httpdata.txt | sort | uniq -c #DinersClub
#egrep -io '6(?:011|5[0-9]{2})[0-9]{12}' httpdata.txt | sort | uniq -c #Discover
#egrep -io '(?:2131|1800|35\d{3})\d{11}' httpdata.txt | sort | uniq -c #JCB

#echo " Looking for emails "
#egrep -io '[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,4}' httpdata.txt | grep -v 'png' | grep -v 'jpg' | grep -v 'jpeg' | grep -v 'gif' | sort | uniq -c


<<<<<<< HEAD
=======
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
>>>>>>> d1c81d14cdf31110f885f0e592bd5184702a6e2d

echo "\nLooking for credit card numbers"

#tcpdump -Ar $filename | grep -i latitude
#tcpdump -Ar $filename | grep -i long=
#tcpdump -Ar $filename | grep -i longitude
#tcpdump -Ar $filename | grep -i password

#tcpdump -Ar $filename | grep -i IMEI
#tcpdump -Ar $filename | grep -i pwd
