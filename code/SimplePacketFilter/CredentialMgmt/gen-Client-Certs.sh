set -a
source ./certificate.config
tmpID=`date +%s | sha1sum | cut -b -10`
tmpPass=`echo ${tmpID} | cut -b -5`
clientName="$tmpID"
clientPassword="$tmpPass"

echo "creating the .p12 files for user: ${clientName} with password ${clientPassword}"
./genClientP12.sh ${clientName} ${clientPassword}

echo "creating the .mobileconfig file"
python ./genIOSConfigXML.py "${clientName}" "${clientPassword}" "${mobileConfigOrgName}" "${mobileConfigConDisplayName}" "${caName}" "${mobileConfigServerHostname}" "${signingCertsPath}${caCertName}" "${clientCertsPath}" 

echo "User Name: ${clientName}"
echo "Password : ${clientPassword}"

