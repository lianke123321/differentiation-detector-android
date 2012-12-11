baseDir="/Users/ashwin/proj-work/meddle/meddle-data/bro-results/"
aggDir="${baseDir}/../bro-aggregate-data"
rm -f ${aggDir}/*.log*
mkdir -p ${aggDir}
cp -vRf ${baseDir}/../bro-headers/* ${aggDir}/
for uDir in ${baseDir}/* ;
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
