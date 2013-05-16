#!/bin/bash

# Note this key is useless without the Meddle.secret file. This key is used to access the private key present in the Meddle.secret file.
# The Meddle.secret file is not present in the git tree! DO NOT ADD IT TO THE GIT TREE!
meddleKey="S@#dvnjkurEqr6uhdfSxVh12d"
baseDir="/user/arao/home/meddle_data/"
decryptDir="${baseDir}/pcap-decrypted/"
encryptDir="${baseDir}/pcap-encrypted/"
newPcapTimeStamp="1365199064" #Apr-05-2013-23-57-1365199064
if [ $# -ne 1 ];
then
  echo "$0 inria/snowmane/sounder/" 
  exit -1
fi 
locName=$1
echo ${locName}
mkdir -p ${decryptDir}
decrypt()
{
    for bName in ${locName}
    do
	for uName in `ls ${encryptDir}/${bName}`
	do
            echo ${bName} ${uName} 
	    uDir=${encryptDir}/${bName}/${uName}
	    if [ -d "${uDir}" ];
	    then
		echo "Dir" ${uDir}		
	    fi
	    uDecDir=${decryptDir}/${uName}
	    mkdir -p ${uDecDir}
	    for encFile in ${uDir}/*.pcap*;
	    do
                newFile=`python isPcapFileNew.py ${encFile} ${newPcapTimeStamp}`
                if [ "${newFile}" == "1" ];
                then    
		    tmpName=`basename ${encFile}`
		    decName=${uDecDir}/${tmpName}.clr
		    echo ${decName}
		    gpg --batch --yes --homedir=${baseDir}/gpg --no-default-keyring --secret-keyring Meddle.secret --keyring Meddle.key -o ${decName} --passphrase "${meddleKey}" --decrypt ${encFile}  # >> /dev/null 2>&1
                #else
                #   echo "Timestamp of ${encFile} < ${newPcapTimeStamp}"
                fi       
	    done
            echo "renaming not performed for sync issues"
            echo "Use this template rename .pcap.enc.clr .pcap ${uDecDir}/*.pcap.enc.clr"
	done
    done
    echo "Now run this find . -size 0 | grep "\.pcap" | xargs rm"
    find ${decryptDir} -size 24c | grep "\.pcap" | xargs rm -f
}   

decrypt
