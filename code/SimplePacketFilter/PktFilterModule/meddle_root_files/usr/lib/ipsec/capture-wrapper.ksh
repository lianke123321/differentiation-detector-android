#!/bin/ksh

sighandler() {
    echo "In the signal handler" >> ${logFile}
}

startcapture () { 
    echo "In the wrapper, starting tcpdump" >> ${logFile}
    echo "${TCPDUMP_BIN} -i ${devCapture} -n ip host ${clientIP} -w -" >> ${logFile}
    echo "${GPG_BIN} --homedir=${GPG_HOME} -o ${dumpName} --keyring ${encPublicKeyRing} -er ${encPublicKeyID} --trust-model always" >> ${logFile}
    echo $$ >> ${lockName}
    cat ${lockName} >> ${logFile} 
    ${TCPDUMP_BIN} -s 96 -i ${devCapture} -n ip host ${clientIP} -w - | ${GPG_BIN} --homedir=${GPG_HOME} -o ${dumpName} --keyring ${encPublicKeyRing} -er ${encPublicKeyID} --trust-model always > /dev/null 2>&1 
}

trap 'sighandler' SIGINT SIGTERM
# The trap in the current version of bash is buggy and it unable to handle blocked signals
startcapture
