# ASSUMES THAT STRONGSWAN HAS BEEN INSTALLED.
# First export the variables.

function genCACerts()
{
    echo "${ipsecBin} pki --gen --outform pem > ${caKeyName}"
    ${ipsecBin} pki --gen --outform pem > ${caKeyName}
    # Sign a certificate using this key 
    ${ipsecBin} pki --self --in ${caKeyName} --dn "C=${caCountry}, O=${caOrg}, CN=${caName}" --ca --outform pem > ${caCertName}
    # Voila! Now you are a CA
}

function installCACerts()
{
    # Assumes that file ${CA_KEY_NAME} and ${CA_CERT_NAME} are present
    # The CA_CERT needs to be installed in the ca certs file. Note we do not need to install the key in the CA certs file.
    # The CA_CERT is required to ensure that the server treats this CA as a valid certifying authority
    echo "Copying ${caCertName} to ${MEDDLE_ROOT}/etc/ipsec.d/cacerts"
    cp -v ${caCertName} ${MEDDLE_ROOT}/etc/ipsec.d/cacerts/

    # This step is required if you want to sign certificates for clients on this machine. 
    echo "Creating ${signingCertsPath}"
    mkdir -v -p ${signingCertsPath}
    mv -v ${caKeyName} ${signingCertsPath} # Note mv is required to keep this directory clean
    mv -v ${caCertName} ${signingCertsPath} 
}

source ./certificate.config
genCACerts
installCACerts
