#!/bin/bash

meddleKey="S@#dvnjkurEqr6uhdfSxVh12d"
baseDir="/home/amy"

unencFldr=${baseDir}/unenc-pcap-data/
encFldr=${baseDir}/pcap-data/

mySignal()
{
   mkdir -p ${unencFldr} 
   cp ${encFldr}/*  ${unencFldr}/    
   for encFile in ${unencFldr}/*.pcap* ;
   do
         echo ${encFile}
 	 gpg --homedir=/data/.gpg --no-default-keyring --secret-keyring /data/.gpg/Meddle.secret --keyring /data/.gpg/Meddle.key -o ${encFile}.unenc --passphrase ${meddleKey} --decrypt ${encFile} >> /dev/null 2>&1
   done  
   rm -f ${unencFldr}/*.enc
   rename s/pcap.enc.unenc/pcap/g  ${unencFldr}/*
#   chown -R amy.pcapread ${unencFldr}
}

#trap 'mySignal' SIGUSR1 SIGUSR2
mySignal
#echo $$ > /data/.decryptor.pid
#while [ 1 ] ;
#do
#   sleep 10000
#done
