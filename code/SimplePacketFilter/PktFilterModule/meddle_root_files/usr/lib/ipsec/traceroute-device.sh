#!/bin/bash

export basePath="${tracerouteDataPath}"
export logFile="${MEDDLE_LOG_PATH}/traceroute.log"

function genDumpName()
{
    timeStamp=`date +%h-%d-%Y-%H-%M-%s`
    #TODO:: Assuming that the last field of the DN in the certificate is the login name of the client 
    export clientID=`echo ${PLUTO_PEER_ID} | awk -F '=' '{print $NF}'`
    export clientIP=`echo ${PLUTO_PEER_CLIENT} | awk -F '/' '{print $1}'`    
    export dumpDateDir=`date +%Y-%h-%d`
    export dumpPath="${basePath}/${dumpDateDir}/${clientID}"
#   export dumpPath="${basePath}/${clientID}/"
    mkdir -p ${dumpPath}
    export dumpName="${dumpPath}/traceroute-${clientID}-${timeStamp}-${PLUTO_ME}-${clientIP}-${PLUTO_PEER}.traceroute"
    echo "Dump Name is ${dumpName}" >> ${logFile}
}


function startTraceRoute()
{
    genDumpName
    ( ${tracerouteBinPath} -i ${ethDeviceName} -n -q 10 ${PLUTO_PEER} > ${dumpName} 2>&1 & ) &
}

function mainFunc()
{    
    mkdir -p ${basePath}
    if [ "${PLUTO_VERB}" == "up-client" ];
    then
        echo "Performing traceroute for ${PLUTO_PEER}"
        startTraceRoute
    fi
    return 0
}

mainFunc
echo "Not Doing Anything now" >> ${logFile}
