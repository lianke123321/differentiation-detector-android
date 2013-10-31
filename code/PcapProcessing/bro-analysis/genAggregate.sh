baseDir="/home/arao/meddle_data/"
broDir="${baseDir}/bro-results/"
broHeadDir="${baseDir}/bro-headers/"
aggDir="${baseDir}/bro-aggregate-data/"
rm -f ${aggDir}/*.log*
mkdir -p ${aggDir}
cp -vRf ${broHeadDir}/* ${aggDir}/
for uDir in ${broDir}/* ;
do   
   uBase=`basename ${uDir}`
   aggBase=`basename ${aggDir}`
   echo ${uBase} ${aggBase}
   if [ "${uBase}" == "${aggBase}" ]; 
   then 
      continue
   fi
   for fName in ${uDir}/* ;
   do  
       echo ${fName}
       baseF=`basename ${fName}`
       tail -n +2 ${fName} >> ${aggDir}/${baseF}
   done
done
