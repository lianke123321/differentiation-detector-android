#!/bin/bash

baseDir="/user/arao/home/controlled_experiments/community_experiments/"
broBin="/home/arao/bro/bin/bro"
srcDir="${baseDir}/parsing-scripts/"
broDir="${baseDir}/bro-results/"
currDir=${PWD}
#for user in test1 test2 test3 amy droid-10-min-amy.pcap
for user in droid-10-min-amy
do   
  echo ${user}
  logDir=${broDir}${user}
  mkdir -p ${logDir}
  cd ${logDir}
  fName=${baseDir}/aggr-pcap-data/${user}.pcap
  echo ${fName}
  ${broBin} -r ${fName} /home/arao/bro/custom-scripts/*  #> /dev/null 2>&1
  cd ${currDir}
done
