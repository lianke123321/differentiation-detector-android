set -a
source ./certificate.config
tmpID=`date +%s | sha1sum | cut -b -10`
tmpPass=`echo ${tmpID} | cut -b -5`
clientName="$tmpID"
clientPassword="$tmpPass"

export clientCertsPath="${clientCertsPath}/${clientName}/"
echo ${clientCertsPath}
mkdir -p ${clientCertsPath}
./genClientP12.sh ${clientName} ${clientPassword}

python genIOSConfigXML.py "${clientName}" "${clientPassword}" "${mobileConfigOrgName}" "${mobileConfigConDisplayName}" "${caName}" "${mobileConfigServerHostname}" "${signingCertsPath}${caCertName}" "${clientCertsPath}" 

python genIOS7ConfigXML.py "${clientName}" "${clientPassword}" "${mobileConfigOrgName}" "${mobileConfigConDisplayName}" "${caName}" "${mobileConfigServerHostname}" "${signingCertsPath}${caCertName}" "${clientCertsPath}"

query="INSERT INTO UserConfigs VALUES (0, '${clientName}', 0);"
echo "${query}"
mysql -u "${dbUserName}" --password="${dbPassword}" -D "${dbName}" -e "${query}"
query="select userID, userName, filterAdsAnalytics from UserConfigs where userName='${clientName}';"
echo "${query}"
mysql -u "${dbUserName}" --password="${dbPassword}" -D "${dbName}" -e "${query}"
echo "${clientName} : XAUTH \"${clientPassword}\"" >> ${MEDDLE_ETC}/ipsec.secrets

authCode=`date +%s``uptime``free`${clientName}
authCode=`echo ${authCode}| md5sum | cut -d ' ' -f 1`
query="insert Into UserAuthMap  SELECT max(userID)+1, '${authCode}' FROM UserAuthMap;"
mysql -u "${dbUserName}" --password="${dbPassword}" -D "${dbName}" -e "${query}"

echo "Making strongswan load the new credentials"
${MEDDLE_ROOT}/usr/sbin/ipsec rereadall 

echo "The certificates have been installed in the ${clientCertsPath}"
echo "For an android device the certificate is ${clientCertsPath}${clientName}.p12"
echo "For an iOS device the config file ${clientCertsPath}${clientName}.mobileconfig"
echo "The installation password is ${clientPassword}"

