#!/bin/bash

baseDir="/Users/ashwin/proj-work/meddle/meddle-data"
currDir=${baseDir}
decryptDir=${currDir}/pcap-decrypted
broDir=${currDir}/bro-results/
mkdir -p ${broDir}
tmpDir=${currDir}/tmpLogs/
mkdir -p ${tmpDir}
srcDir="/Users/ashwin/proj-work/meddle/ashwin-meddle/meddle/code/PcapProcessing/bro-analysis/gen-analysis-logs/"
for uDir in ${decryptDir}/*;
do
    uName=`basename ${uDir}`
    echo ${uName}
    #if [ "${uName}" != "will-ipad" ];
    #then
    #    continue
    #fi 
    broUDir=${broDir}/${uName}
    mkdir -p ${broUDir}
    rm -f ${tmpDir}/*
    cp -vRf ${currDir}/bro-headers/* ${broUDir}

    cnt=1
    totCnt=1
    for fName in ${uDir}/*.pcap*;
    do
	cd ${tmpDir}
        rm -f ${tmpDir}/*
	bro -r ${fName} > /dev/null 2>&1
        globalIP=`python ${srcDir}/getIPFromFile.py ${fName} 1`
        localIP=`python ${srcDir}/getIPFromFile.py ${fName} 2`
	#echo ${globalIP} ${localIP}
        for logFile in *.log;
	do
            sed -e s/"${localIP}"/"${globalIP}"/g ${logFile} > ${logFile}.tmp
            cat ${logFile}.tmp >> ${broUDir}/${logFile}
	done
        # Will not work for traceroutes/sshs to localmachines, etc .. will not work for x.10.11.x
        #cnt=`grep -c "10\.11\." ${broUDir}/conn.log`
        #echo ${cnt}
        #if [ "${cnt}" != "0" ] ;
        #then
        #   echo ${fName} ${localIP} ${globalIP}
        #   cat ${tmpDir}/http.log
        #   exit 
        #fi
        cnt=$((cnt+1))
        if [ $cnt -gt 25 ] ;
        then
            totCnt=$((totCnt+cnt))
            echo $totCnt
            cnt=1
        fi
	cd - > /dev/null 2>&1
    done
    cd ${broUDir}
    for logFile in *.log;
    do
	sed '/^#/d' ${logFile} > ${uName}.log
	mv ${uName}.log ${logFile}
    done
    cd - > /dev/null 2>&1	
    rm -Rf ${tmpDir}/*
    #rmdir ${tmpDir}
done
