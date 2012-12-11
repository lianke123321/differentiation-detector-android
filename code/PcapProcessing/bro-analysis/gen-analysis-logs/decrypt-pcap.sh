#!/bin/bash

meddleKey="S@#dvnjkurEqr6uhdfSxVh12d"
baseDir="/Users/ashwin/proj-work/meddle/meddle-data"
currDir=${baseDir}
decryptDir="${currDir}/pcap-decrypted"
mkdir -p ${decryptDir}
decrypt()
{
    for bName in snowmane sounder
    do
	for uName in `ls ${currDir}/${bName}`
	do
            echo ${bName} ${uName} 
#            if [ "${uName}" == "arao-droid" ]  || [ "${uName}" == "dave-droid" ] || [ "${uName}" == "arao-ipod" ] || [ "${uName}" == "dave-iphone" ] || [ "${uName}" == "dave-ipad" ] ||   [ "${uName}" == "1bb03d7910" ] || [ "${uName}" == "parikshan-droid" ] ;
#            then
#                 continue
#            fi	
	    uDir=${currDir}/${bName}/${uName}
	    if [ -d "${uDir}" ];
	    then
		echo "Dir" ${uDir}		
	    fi
	    uDecDir=${decryptDir}/${uName}
	    mkdir -p ${uDecDir}
	    for encFile in ${uDir}/*.pcap*;
	    do
		tmpName=`basename ${encFile}`
		decName=${uDecDir}/${tmpName}.clr
#		echo ${decName}
		gpg --homedir=${currDir}/gpg --no-default-keyring --secret-keyring Meddle.secret --keyring Meddle.key -o ${decName} --passphrase ${meddleKey} --decrypt ${encFile}  # >> /dev/null 2>&1
	    done
            #rename .pcap.enc.clr .pcap ${uDecDir}/*	
	done
    done
    echo "Now run this find . -size 0 | grep "\.pcap" | xargs rm"
    find ${decryptDir} -size 24c | grep "\.pcap.clr" | xargs rm -f
}   

decrypt
