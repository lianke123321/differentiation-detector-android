#!/bin/bash

basePath="/data/pcap-data/"
logFile="${basePath}/pkt-capt.log"
ipLookUpFile="${basePath}/ipLookUp.txt"
devCapture="tun0"
passPhrase="manger preservatifs ou conservatifs"

function logState()
{
    printenv >> ${logFile}
}

function genDumpName()
{
    timeStamp=`date +%h-%d-%Y-%H-%M-%s`
    #TODO:: Assuming that the last field of the DN in the certificate is the login name of the client 
    clientID=`echo ${PLUTO_PEER_ID} | awk -F '=' '{print $NF}'`
    clientIP=`echo ${PLUTO_PEER_CLIENT} | awk -F '/' '{print $1}'`    
    dumpPath="${basePath}/${clientID}/"
    mkdir -p ${dumpPath}
    dumpName="${dumpPath}/tcpdump-${clientID}-${timeStamp}-${PLUTO_ME}-${clientIP}-${PLUTO_PEER}.pcap.enc"
    echo "Dump Name is ${dumpName}" >> ${logFile}
}

function genLockName()
{
    # Assumes genDumpName has been called previously
    lockName=${basePath}/"capt-${clientID}.lock"
    echo ${lockName} >> ${logFile}
}

function stopLastTcpdump()
{
    # Assumes genLockName has been called previously 
    # lockLst=`find ${basePath} -name "${lockPrefix}"`
    if [ -e ${lockName} ] && [ -f ${lockName} ] && [ -s ${lockName} ] ;
    then 
        echo "Stopping for pid" >> ${logFile}
        cat ${lockName} >> ${logFile}
        while read line
        do
	    #kill ${line} >> $logFile 2>&1         
            # TODO:: CHECK IF THIS IS INDEED TCPDUMP .. check way to flush packets 
            kill ${line} >> ${logFile} 2>&1
            echo "Killing ${line} " >> ${logFile} 2>&1
        done < "${lockName}"
    fi
    rm -f ${lockName}
    echo "Removed the lock file ${lockName}" >> ${logFile}
}

function stopEncPacketCapture()
{
    echo "stopping current capture" >> ${logFile}
    genDumpName
    genLockName
    stopLastTcpdump    
}

function startEncPacketCapture()
{
    stopEncPacketCapture
    echo "starting Capture" >> ${logFile}
    { (tcpdump -i ${devCapture} -n ip host ${clientIP} -w - & echo $! >${lockName}) | gpg -o ${dumpName} -c --passphrase ${passPhrase} > /dev/null 2>&1 & } &
#   tcpdump -i ${devCapture} -n ip host ${clientIP} -w ${dumpName} >> ${logFile} 2>&1  &
#   echo $! >  ${lockName}
    echo "Started Enc Packet capture" >> ${logFile} 
    cat ${lockName} >> ${logFile} 
}

function updateIPLookUp()
{
    echo "${timeStamp} ${clientIP} ${clientID} ${PLUTO_PEER} ${PLUTO_ME} ${PLUTO_VERB}" >> ${ipLookUpFile}
}

function mainFunc()
{    
    mkdir -p ${basePath}
    logState
    if [ "${PLUTO_VERB}" == "up-client" ];
    then
	startEncPacketCapture
	updateIPLookUp
     # The client is up
    elif [ "${PLUTO_VERB}" == "down-client" ];
    then
    # the client is down
	stopEncPacketCapture
	updateIPLookUp
    else
	echo "WARNING:: PLUTO_VERB=${PLUTO_VERB} is not supported" >> ${logFile}
    fi
    return 0
}

mainFunc
echo "Not Doing Anything now" >> ${logFile}
