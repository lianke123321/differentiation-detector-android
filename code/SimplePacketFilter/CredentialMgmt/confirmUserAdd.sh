source certificate.config

clientUser=$1
clientPassword=$2

query="INSERT INTO UserConfigs VALUES (0, '${clientUser}', 0)"
#mysql -u ${dbUserName} --password=${dbPassword} -D ${dbName} -e ${query}
query="select * from UserConfigs where UserName=${clientUser}"
#mysql -u ${dbUserName} --password=${dbPassword} -D ${dbName} -e ${query}
echo "${clientUser} : XAUTH ${clientPassword}" 

