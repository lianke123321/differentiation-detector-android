#!/bin/bash
# Goes through all pcaps in a directory, looking for Android ID, Username, Contacts, Password, Location 

directory=$1
#timestampstxt=$2
echo "Reading $directory"

#cat $timestampstxt | awk -F ' : ' '{print $2}' | awk -F ' ' '{print $2,$3,$6,$4}'| awk -F ':' '{print $1"\:"$2}' > times.txt

for file in $directory/*
do

#sh grep -iForStuff.sh $file  > grepped.txt
tcpdump -Ar "$file" > grepped.txt

echo "Name of File: $file"
#AndroidIDa
leaked="0"
if [ -n "$(grep -i '9419f52ee69ffcba' grepped.txt)" ];then  leaked="1"; fi;  

echo "AndroidID: $leaked"

#DeviceID
leaked="0"
if [ -n "$(grep -i '355031040753366' grepped.txt)" ];then  leaked="1"; fi;  

echo "DeviceID: $leaked"

#Username
leaked="0"
if [ -n "$(grep -i 'testdroidmeddle' grepped.txt)" ];then  leaked="1"; fi;  

echo "Username: $leaked"

#Password
leaked="0"
if [ -n "$(grep -i 'gameofthrones1' grepped.txt)" ];then  leaked="1"; fi;  

if [ -n "$(grep -i 'meddlepw' grepped.txt)" ];then  leaked="1"; fi;  

echo "Password: $leaked"

#Contact
leaked="0"
if [ -n "$(grep -i 'amytang9' grepped.txt)" ];then  leaked="1"; fi;  

if [ -n "$(grep -i 'arya' grepped.txt)" ];then  leaked="1"; fi;  

if [ -n "$(grep  -i 'AryaStark' grepped.txt)" ];then  leaked="1"; fi;  

if [ -n "$(grep -i '5556667777' grepped.txt)" ];then  leaked="1"; fi;  

if [ -n "$(grep -i '(555)666-7777' grepped.txt)" ];then  leaked="1"; fi;  

echo "Contact: $leaked"

#Location
leaked="0"
if [ -n "$(egrep -io '[^a-zA-Z]?lat([^a-zA-Z]|itude).*[0-9]+(\.?)[0-9]+' grepped.txt )"	 ];then  leaked="1"; fi;  
echo "Location: $leaked"

done >> pcapbypcapresults.txt

