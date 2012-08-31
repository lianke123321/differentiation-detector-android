#!/bin/bash

# Script to generate the certificates for each user
# Based on the steps presented in strongswan site
# Assumes IPSEC and OPENSSL are defined and available


IPSEC=`which ipsec`
OPENSSL=`which openssl`
MYPID="$$"
if [ $# -ne 2 ];
then
    echo "${MYPID}::$0 <clientName> <clienPassword>"
    exit 1    	 
fi
clientName="$1"
clientPassword="$2"

if [ "${IPSEC}" == "" ] || [ "${OPENSSL}" == "" ];
then
    echo "my pid: ${MYPID} ipsec is available at: ${IPSEC} and openssl is available at ${OPENSSL}"
    exit 2;
fi

#TODO:: Take all CA related info from a conf file or as arguments
ipSecCertPath="/data/etc/ipsec.d/"
caCert="${ipSecCertPath}/cacerts/caCert.pem"
caKey="${ipSecCertPath}/private/caKey.pem"
DNstr="C=US, O=snowmane, CN=${clientName}"
caName="snowmane CA" # The name used in the certificate
CERTPATH="./"
p12File="${CERTPATH}/${clientName}.p12"

keyFile="${CERTPATH}/${clientName}Key${MYPID}.pem"
certFile="${CERTPATH}/${clientName}Cert${MYPID}.pem"
androidFile="${CERTPATH}/${clientName}.crt"

${IPSEC} pki --gen --outform pem > ${keyFile}
# echo "${keyFile} created using ${IPSEC}"
# cat ${keyFile}
${OPENSSL} rsa -in ${keyFile} -check -noout > /dev/null 2>&1
if [ $? -ne 0 ];
then
    echo "Error Creating Key File for the Certificate"
    exit 3;
fi
# Required the eval stuff to get the quotes for DN working..
cmd=""${IPSEC}" pki --pub --in "${keyFile}" | "${IPSEC}" pki --issue --cacert "${caCert}" --cakey "${caKey}" --dn \""${DNstr}"\" --outform pem > ${certFile}"
eval ${cmd}
"${OPENSSL}" x509 -in "${certFile}" -noout > /dev/null 2>&1
if [ $? -ne 0 ];
then
    echo "Error Creating Certificate File"
    exit 4;
fi
# echo "${certFile} created"
#openssl pkcs12 -export -inkey /tmp/abcKey6906.pem -in /tmp/abcCert6906.pem -name "client" -certfile /home/arao/etc/ipsec.d/cacerts/caCert.pem -caname "snowmane CA" -out abc.p12 -passout pass:hello

# Secure way is to use env variables
"${OPENSSL}" pkcs12 -export -inkey "${keyFile}" -in "${certFile}" -name "${clientName}" -passout pass:"${clientPassword}" -certfile "${caCert}" -caname \""${caName}"\" -out "${p12File}"
cp ${certFile} ${androidFile}
# TODO:: check the p12 file
# ${OPENSSL} pkcs12 -info -in ${p12File} -passin env:${clientPassword} TODO:: specify PEM key 

