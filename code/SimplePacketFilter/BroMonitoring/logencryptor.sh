#! /usr/bin/env bash

set -a 
source /opt/meddle/meddle.config
inpName=$1
dumpName=$2
isHttp=`echo ${dumpName} | grep "http"`
echo "${dumpName} ${isHttp}"
sigLogName=/opt/meddle/logs/assignSignatures.log
tmpLogName="/opt/meddle/logs/tmp-http.log"
if [ "${isHttp}" != "" ];
then

    echo "Assigning Signatures to ${tmpLogName} ${inpName} ${dumpName}" >> ${sigLogName}
    if [ -r ${inpName} ];
    then
        echo "File ${inpName} Exists -- starting analysis" >>  ${sigLogName}
        cp -f ${inpName} ${tmpLogName}
        ( /opt/meddle/bro/bin/AssignSignatures.R --args /opt/meddle/meddle.config ${tmpLogName} >> ${sigLogName} 2>&1 & ) &
    fi
fi
${gpgBinPath} --homedir=${gpgHome} -o ${dumpName} --keyring ${gpgPublicKeyRing} -er ${gpgPublicKeyID} --trust-model always ${inpName}
