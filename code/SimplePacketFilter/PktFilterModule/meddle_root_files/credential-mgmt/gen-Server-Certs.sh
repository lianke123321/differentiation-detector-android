# ASSUMES THAT STRONGSWAN HAS BEEN INSTALLED.
# First export the variables.

function genServerCerts()
{
    echo "Generating the key ${serverKeyName}"
    ${ipsecBin} pki --gen --outform pem > ${serverKeyName}
    # Sign a certificate using this key 

    echo "Creating the certificate ${serverCertName}"
    ${ipsecBin} pki --pub --in ${serverKeyName} | ${ipsecBin} pki --issue --cacert ${signingCertsPath}${caCertName} --cakey ${signingCertsPath}${caKeyName} --dn "C=${caCountry}, O=${caOrg}, CN=${serverHostname}" --san="${serverHostname}" --flag serverAuth --flag ikeIntermediate --outform pem > ${serverCertName}
    # Voila! Now you have a valid certificate
}

function installServerCerts()
{
    # Assumes that file ${SERVER_KEY_NAME} and ${SERVER_CERT_NAME} are present
    # The CA_CERT needs to be installed in the ca certs file. Note we do not need to install the key in the CA certs file.
    # The CA_CERT is required to ensure that the server treats this CA as a valid certifying authority
    echo "Moving certificates to appropriate location"
    mv -v ${serverCertName} ${MEDDLE_ROOT}/etc/ipsec.d/certs # mv required to keep this directory clean
    mv -v ${serverKeyName} ${MEDDLE_ROOT}/etc/ipsec.d/private
}

source ./certificate.config
genServerCerts
installServerCerts
