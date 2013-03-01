set -a
source certificate.config
tmpID=`date +%s | sha1sum | cut -b -10`
tmpPass=`echo ${tmpID} | cut -b -5`
clientName="$tmpID"
clientPassword="$tmpPass"

gen-Client-P12.sh ${clientName} ${clientPassword}

python genIOSConfigXML.py ${clientName} ${clientPassword} ${mobileConfigOrgName} ${mobileConfigConDisplayName} ${caName} ${mobileConfigServerHostname} ${signingCertsPath}${caCertName} ${clientCertsPath} 

