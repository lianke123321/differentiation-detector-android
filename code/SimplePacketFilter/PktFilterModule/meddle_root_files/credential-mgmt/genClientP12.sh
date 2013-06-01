#!/bin/bash

# Script to generate the certificates for each user
# Based on the steps presented in strongswan site
# Assumes IPSEC and OPENSSL are defined and available

#################################################################################
# 1. Get the inputs 
if [ $# -ne 2 ];
then
    echo "${MYPID}::$0 <clientName> <clienPassword>"
    exit 1    	 
fi
clientName=$1
clientPassword=$2
################################################################################
# 2. DECLARE THE VARIABLES REQUIRED TO GENERATE THE CERTIFICATES
caCert="${signingCertsPath}/${caCertName}"
caKey="${signingCertsPath}/${caKeyName}"
mkdir -p ${clientCertsPath}
DNstr="C=${caCountry}, O=${caOrg}, CN=${clientName}"
OPENSSL=`which openssl`
p12File="${clientCertsPath}/${clientName}.p12"
#MYPID="$$"
MYPID="" # FOO! :(
keyFile="${clientCertsPath}/${clientName}Key${MYPID}.pem"
certFile="${clientCertsPath}/${clientName}Cert${MYPID}.pem"
# The android file is useful for testing different accounts on the same device!
androidFile="${clientCertsPath}/${clientName}.crt"

################################################################################
# 3. CHECK IF THE BINARIES REQUIRED TO SIGN THE CERTIFICATES ARE AVAILABLE
if [ "${ipsecBin}" == "" ] || [ "${OPENSSL}" == "" ];
then
    echo "my pid: ${MYPID} ipsec is available at: ${ipsecBin} and openssl is available at ${OPENSSL}"
    exit 2;
fi

################################################################################
# 4. Create the private key and check if it is a valid key
echo "Creating the Key: ${keyFile}"
${ipsecBin} pki --gen --outform pem > ${keyFile}
# echo "${keyFile} created using ${IPSEC_BIN}"
# cat ${keyFile}
${OPENSSL} rsa -in ${keyFile} -check -noout > /dev/null 2>&1
if [ $? -ne 0 ];
then
    echo "Error Creating Key File for the Certificate"
    exit 3;
fi

################################################################################
# 4. Use the key and send (pipe) it to the CA. The CA then signs the signature
# using its private key. Check if the certificate signed by the CA is valid.
echo "Creating the Certificate: ${certFile}"
cmd=""${ipsecBin}" pki --pub --in "${keyFile}" | "${ipsecBin}" pki --issue --cacert "${caCert}" --cakey "${caKey}" --dn \""${DNstr}"\" --outform pem > ${certFile}"
eval ${cmd}
# Stupid bash bug made me use eval to get the quotes for DN working :(.
"${OPENSSL}" x509 -in "${certFile}" -noout > /dev/null 2>&1
if [ $? -ne 0 ];
then
    echo "Error Creating Certificate File"
    exit 4;
fi
# echo "${certFile} created"

################################################################################
# 5. Now convert it to the .p12 format. .p12 is required by Android devices
# and also to create the .mobileconfig files for iOS devices.
# An example of creating the .p12 file is as follows.
#openssl pkcs12 -export -inkey /tmp/abcKey6906.pem -in /tmp/abcCert6906.pem -name "client" -certfile /home/arao/etc/ipsec.d/cacerts/caCert.pem -caname "snowmane CA" -out abc.p12 -passout pass:hello

# Note I am using shell variables because it is considered to be a secure way
# to send passwords to programs :p !
echo "Generating the .p12 file:${p12File}"
"${OPENSSL}" pkcs12 -export -inkey "${keyFile}" -in "${certFile}" -name "${clientName}" -passout pass:"${clientPassword}" -certfile "${caCert}" -caname \""${caName}"\" -out "${p12File}"
# The android file is useful for testing different accounts on the same android device
#cp ${certFile} ${androidFile}
echo "Done! Created ${keyFile} ${certFile} ${p12File} for user ${clientName} with password ${clientPassword}"

#python genIOSConfigXML.py ${clientName} ${clientPassword}
#echo "Created ${clientName} ${clientPassword}"
# TODO:: check the p12 file
# ${OPENSSL} pkcs12 -info -in ${p12File} -passin env:${clientPassword} TODO:: specify PEM key 
