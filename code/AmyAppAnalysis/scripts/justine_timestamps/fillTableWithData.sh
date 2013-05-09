#!/bin/bash

directory=$1
#timestampstxt=$2
echo "Reading $directory"

#cat $timestampstxt | awk -F ' : ' '{print $2}' | awk -F ' ' '{print $2,$3,$6,$4}'| awk -F ':' '{print $1"\:"$2}' > times.txt

for file in $directory/*
do

#sh grepForStuff.sh $file  > grepped.txt
tcpdump -Ar "$file" > grepped.txt

echo "Name of File: $file"
#AndroidIDa
leaked="0"
if [ -n "$(grep '9419f52ee69ffcba' grepped.txt)" ];then  leaked="1"; fi;  

echo "AndroidID: $leaked"

#DeviceID
leaked="0"
if [ -n "$(grep '355031040753366' grepped.txt)" ];then  leaked="1"; fi;  

echo "DeviceID: $leaked"

#Username
leaked="0"
if [ -n "$(grep 'testdroidmeddle' grepped.txt)" ];then  leaked="1"; fi;  

echo "Username: $leaked"

#Password
leaked="0"
if [ -n "$(grep 'gameofthrones1' grepped.txt)" ];then  leaked="1"; fi;  

if [ -n "$(grep 'meddlepw' grepped.txt)" ];then  leaked="1"; fi;  

echo "Password: $leaked"

#Contact
leaked="0"
if [ -n "$(grep 'amytang9' grepped.txt)" ];then  leaked="1"; fi;  

if [ -n "$(grep 'arya' grepped.txt)" ];then  leaked="1"; fi;  

if [ -n "$(grep 'stark' grepped.txt)" ];then  leaked="1"; fi;  

if [ -n "$(grep '5556667777' grepped.txt)" ];then  leaked="1"; fi;  

if [ -n "$(grep '(555)666-7777' grepped.txt)" ];then  leaked="1"; fi;  

echo "Contact: $leaked"

#Location
leaked="0"
if [ -n "$(egrep -io '[^a-zA-Z]?lat([^a-zA-Z]|itude).*[0-9]+(\.?)[0-9]+' grepped.txt )"	 ];then  leaked="1"; fi;  
echo "Location: $leaked"

done >> pcapbypcapresults.txt

