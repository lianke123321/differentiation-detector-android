#!/bin/bash

if [ $# -ne 1 ]
then
  echo "$# $0 <userName>"
  exit -1
fi
reqUserName=$1
baseDir="/user/arao/home/meddle_data/"
broHome="/user/arao/home/bro/"
broBin="${broHome}/bin/bro"
broCustom="${broHome}/custom-scripts/"
srcDir="${baseDir}/parsing-scripts/"
decryptDir="${baseDir}/pcap-decrypted/"
broDir="${baseDir}/bro-results/"
mkdir -p ${broDir}
tmpDir="${baseDir}/tmpLogs/tmp-${reqUserName}/"
mkdir -p ${tmpDir}
for uDir in ${decryptDir}/*;
do
    uName=`basename ${uDir}`
    if [ "${uName}" != "${reqUserName}" ];
    then
        echo "${uName} != ${reqUserName}"
        continue
    fi 
    echo "Running Bro for ${uName}"
    broUDir=${broDir}/${uName}
    mkdir -p ${broUDir}
    rm -f ${tmpDir}/*
    cp -vRf ${baseDir}/bro-headers/* ${broUDir}

    cnt=0
    totCnt=0
    for fName in ${uDir}/*.pcap*;
    do
        cd ${tmpDir}
        rm -f ${tmpDir}/*
        ${broBin} -r ${fName} ${broCustom}/*.bro  > /dev/null 2>&1
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
        if [ $cnt -eq 25 ] ;
        then
            totCnt=$((totCnt+cnt))
            echo $totCnt
            cnt=0
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
    rm -Rf ${tmpDir}/.state
    #rmdir ${tmpDir}
done
rm -Rf ${tmpDir}/.state
rmdir ${tmpDir}

