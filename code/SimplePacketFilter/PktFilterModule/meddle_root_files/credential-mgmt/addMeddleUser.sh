set -a
source ./certificate.config
tmpID=`date +%s | sha1sum | cut -b -10`
tmpPass=`echo ${tmpID} | cut -b -5`
clientName="$tmpID"
clientPassword="$tmpPass"

./gen-Client-P12.sh ${clientName} ${clientPassword}

python genIOSConfigXML.py ${clientName} ${clientPassword} ${mobileConfigOrgName} ${mobileConfigConDisplayName} ${caName} ${mobileConfigServerHostname} ${signingCertsPath}${caCertName} ${clientCertsPath} 

query="INSERT INTO UserConfigs VALUES (0, '${clientName}', 0)"
mysql -u ${dbUserName} --password=${dbPassword} -D ${dbName} -e ${query}
query="select * from UserConfigs where UserName=${clientUser}"
mysql -u ${dbUserName} --password=${dbPassword} -D ${dbName} -e ${query}
echo "${clientName} : XAUTH ${clientPassword}" >> ${MEDDLE_ETC}/ipsec.secrets

echo "The certificates have been installed in the ${clientCertsPath}"
echo "For an android device the certificate is ${clientCertsPath}${clientName}.p12"
echo "For an iOS device the config file ${clientCertsPath}${clientName}.mobileconfig"

