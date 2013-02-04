#!/bin/bash
udp=0
thing = 0
https = 0
all=0

for file in arao-droid/*
do
  thing+=$(tcpdump -tnr $file port 80 | wc -l)
  https+=$(tcpdump -tnr $file port 443 | wc -l)
  udp=$(($udp + $(tcpdump -tnr $file port 53 | wc -l)))
  all+=$(tcpdump -tnr $file| wc -l)
done

echo "UDP: " + $udp
sum=0
for word in $thing 
do
  sum=$(($sum+$word))
done
echo $sum

httpssum=0
for word2 in $https
do
  httpssum=$(($httpssum+$word2))
done
echo $httpssum

allsum=0
for word3 in $all
do
  allsum=$(($allsum+$word3))
done
echo $allsum

echo "HTTP Percentage: "+ $(($sum/$allsum))
echo "HTTPS Percentage: " + $(($httpssum/$allsum))
