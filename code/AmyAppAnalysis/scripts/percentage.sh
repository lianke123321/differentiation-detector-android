#!/bin/bash
udp=0
thing = 0
https = 0
all=0

for line in packets.txt

do
  thing=$(($thing+$(cut -f1 $line)))
done

echo $thing

#allsum=0
#for word3 in $all
#do
#  allsum=$(($allsum+$word3))
#done
#echo $allsum

#echo "HTTP Percentage: "+ $(($sum/$allsum))
#echo "HTTPS Percentage: " + $(($httpssum/$allsum))
