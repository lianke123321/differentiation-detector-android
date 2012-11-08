#!/bin/bash

export basePath="/data/pcap-data/"
export logFile="${basePath}/pkt-capt.log"
export ipLookUpFile="${basePath}/ipLookUp.txt"
export devCapture="tun0"
export encPublicKeyID="Meddle"
export TCPDUMP_BIN="/usr/sbin/tcpdump" 
export GPG_BIN="/usr/bin/gpg"
export GPG_HOME="/data/.gpg"
export encPublicKeyRing="${GPG_HOME}/Meddle.key"

function logState()
{
    echo "Env variables for pktcapt" >> ${logFile}
    echo "$PLUTO_ME $PLUTO_PEER $PLUTO_PEER_ID $PLUTO_PEER_CLIENT ${PLUTO_VERB} " >> ${logFile}
    printenv >> ${logFile}
}

function genDumpName()
{
    timeStamp=`date +%h-%d-%Y-%H-%M-%s`
    #TODO:: Assuming that the last field of the DN in the certificate is the login name of the client 
    export clientID=`echo ${PLUTO_PEER_ID} | awk -F '=' '{print $NF}'`
    export clientIP=`echo ${PLUTO_PEER_CLIENT} | awk -F '/' '{print $1}'`    
    export dumpPath="${basePath}/${clientID}/"
    mkdir -p ${dumpPath}
    export dumpName="${dumpPath}/tcpdump-${clientID}-${timeStamp}-${PLUTO_ME}-${clientIP}-${PLUTO_PEER}.pcap.enc"
    echo "Dump Name is ${dumpName}" >> ${logFile}
}

function genLockName()
{
    # Assumes genDumpName has been called previously
    export lockName=${basePath}/"capt-${clientID}.lock"
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
            reqPPID=${line} # The parent pid is of the ksh wrapper
            echo "Parent of the tcpdump process is ${reqPPID}" >> ${logFile}
            for cnt in 1 2 3 4 5 6 7 8 9 10 
            do 
                reqPID=`pgrep -o -P ${reqPPID}` 
                echo "Attempt ${cnt} to kill the process ${reqPID}" >> ${logFile}  
                reqStr=`ps axo pid,comm | grep ${reqPID} | grep "tcpdump"`
                if [ "${reqStr}" != "" ];
                then
                    echo "The PID we have ${reqPID} is of a tcpdump process" >> ${logFile}    
                    kill -TERM ${reqPID}                      
                    sleep 0.001
                fi
                reqStr=`ps axo pid,comm | grep ${reqPID} | grep "tcpdump"`
                if [ "${reqStr}" == "" ];
                then
                    echo "We have killed the tcpdump process ${reqPID} " >> ${logFile}
                    break;
                fi
            done
            if [ ${cnt} -ge 10 ];
            then
               echo "Trying to kill the parent now ${reqPPID}" >> ${logFile} 
               pkill -TERM -P ${reqPPID}
               kill -9 ${reqPPID}  
            fi
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
    ( /data/usr/lib/ipsec/capture-wrapper.ksh > /dev/null 2>&1 & ) &
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

function sigHandler()
{
    echo "RECEIVED SIGNAL" >>  /data/pcap-data/sig.log
}

trap 'sigHandler' SIGTERM SIGINT

mainFunc
echo "Not Doing Anything now" >> ${logFile}