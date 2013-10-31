baseDir="/user/arao/home/meddle_data/"
meddleDecPcapData="${baseDir}/pcap-decrypted/"
getIPFromFile="./getIPFromFile.py" 
rawClientIP="${baseDir}/miscData/rawClientIPList.txt"
ipInfo="${baseDir}/miscData/clientIPInfo.txt"
mkdir -p ${baseDir}/miscData/
rm -f ${rawClientIP}
cnt=0
tmpCnt=0
lstElems=`find ${meddleDecPcapData} -name "*.pcap*"`
#echo ${lstElems}
for elem in ${lstElems} 
do
   cnt=$((cnt+1))
done
echo "Total Elements ${cnt}"
totCnt=${cnt}
cnt=0 
for elem in ${lstElems} 
do 
     python ${getIPFromFile} ${elem} 1 >> ${rawClientIP}; 
     cnt=$((cnt+1))
     tmpCnt=$((tmpCnt+1))
     if [ $tmpCnt -eq 100 ]
     then
         tmpCnt=0
         dstr=`date +%s`   
         echo "${dstr} ${cnt} of ${totCnt}"
     fi
done
uniq ${rawClientIP} | sort | uniq > tmp.txt
echo "begin" > ${rawClientIP}
echo "verbose" >> ${rawClientIP}
cat tmp.txt >> ${rawClientIP}
echo "end" >> ${rawClientIP}

nc whois.cymru.com 43 < ${rawClientIP} | sort -n | uniq  > tmp.txt 

echo -n -e "as\tip_prefix\tcountry\tas_info\tissue_date\tisp_info\n" > ${ipInfo}
#AS network country as_info issue_date provider_info" > ${ipInfo}
awk -F "|" '{print $1 " " $3 " " $4 " " $5 " " $6 " " $7 " " $8 " " $9}' tmp.txt | sort | uniq >> ${ipInfo}
# Does not work on MAC http://stackoverflow.com/questions/5398395/how-can-i-insert-a-tab-character-with-sed-on-os-x
echo -n -e "0\t172.16.0.0/12\tUS\t-\t-\tUniversity Private Address Space\n" >> ${ipInfo}
echo -n -e "0\t192.168.0.0/16\tUS\t-\t-\tUniversity Private Address Space\n" >> ${ipInfo}
echo -n -e "0\t10.0.0.0/8\tUS\t-\t-\tUniversity Private Address Space\n">>${ipInfo}
sed  's/\s\{2\,\}/\t/g' ${ipInfo} > tmp.txt
sed "s/\s$//g" tmp.txt > ${ipInfo}
#rm tmp.txt
# Remove trailing white space

