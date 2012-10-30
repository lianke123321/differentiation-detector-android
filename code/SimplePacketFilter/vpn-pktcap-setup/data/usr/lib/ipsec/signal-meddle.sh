#!/bin/bash

basePath="/data/pcap-data/"
logFile="${basePath}/pkt-capt.log"
signalCMD="/data/usr/sbin/SignalUserUpDown"

function logState()
{
    echo "Env variables while signaling user ${PLUTO_VERB} " >> ${logFile}
    printenv >> ${logFile}
}

function genParams()
{
    #TODO:: Assuming that the last field of the DN in the certificate is the login name of the client 
    clientID=`echo ${PLUTO_PEER_ID} | awk -F '=' '{print $NF}'`
    clientIP=`echo ${PLUTO_PEER_CLIENT} | awk -F '/' '{print $1}'`    
}

function signalUP()
{
    echo "Signalling ${signalCMD} ${clientID} ${clientIP} up" >> ${logFile}
    ${signalCMD} ${clientID} ${clientIP} ${PLUTO_PEER} ${PLUTO_ME} up >> ${logFile} 2>&1
    retV=$?	    
    # TODO:: THE ERROR HANDLING NEEDS TO BE IMPROVED  
    if [ ${retV} -ne 0 ];
    then 
       echo "Error in signalling the user ${clientID} ${clientIP} status ${PLUTO_VERB}" >> ${logFile}
    else
       echo "Success in setting the user ${clientID} ${clientIP} status ${PLUTO_VERB}" >> ${logFile}
    fi   
}

function signalDown()
{
    echo "Signalling ${signalCMD} ${clientID} ${clientIP} down" >> ${logFile}
    ${signalCMD} ${clientID} ${clientIP} ${PLUTO_PEER} ${PLUTO_ME} down >> ${logFile} 2>&1
    retV=$?	    
    # TODO:: THE ERROR HANDLING NEEDS TO BE IMPROVED  
    if [ ${retV} -ne 0 ]
    then
       echo "Error in signalling the user ${clientID} ${clientIP} status ${PLUTO_VERB}" >> ${logFile}
    else
       echo "Success in setting the user ${clientID} ${clientIP} status ${PLUTO_VERB}" >> ${logFile}
    fi   
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
