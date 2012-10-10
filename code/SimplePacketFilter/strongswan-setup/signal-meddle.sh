#!/bin/bash

basePath="/data/pcap-data/"
logFile="${basePath}/pkt-capt.log"
signalCMD="/data/usr/sbin/SignalUserUpDown"

function genParams()
{
    timeStamp=`date +%h-%d-%Y-%H-%M-%s`
    #TODO:: Assuming that the last field of the DN in the certificate is the login name of the client 
    clientID=`echo ${PLUTO_PEER_ID} | awk -F '=' '{print $NF}'`
    clientIP=`echo ${PLUTO_PEER_CLIENT} | awk -F '/' '{print $1}'`    
    echo "Dump Name is ${dumpName}" >> ${logFile}
}

function signalUP()
{
    ${signalCMD} ${clientID} ${clientIP} up		
    echo "Signalling ${signalCMD} ${clientID} ${clientIP} up" >> ${logFile}
}

function signalDown()
{
    ${signalCMD} ${clientID} ${clientIP} down
    echo "Signalling ${signalCMD} ${clientID} ${clientIP} down" >> ${logFile}
}

function mainFunc()
{    
    mkdir -p ${basePath}
    logState
    genParams
    if [ "${PLUTO_VERB}" == "up-client" ];
    then
	signalUP
     # The client is up
    elif [ "${PLUTO_VERB}" == "down-client" ];
    then
    # the client is down
        signalDown
    else
	echo "WARNING:: PLUTO_VERB=${PLUTO_VERB} is not supported" >> ${logFile}
    fi
    return 0
}

mainFunc
