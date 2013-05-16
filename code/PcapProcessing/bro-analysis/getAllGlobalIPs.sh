meddleDecPcapData="/Users/ashwin/proj-work/meddle/meddle-data/pcap-decrypted/"
getIPFromFile="./getIPFromFile.py" 
globalIPMeta="${meddleDecPcapData}/../ipData/globalIPMeta.txt"
globalIPAsMeta="${meddleDecPcapData}/../ipData/globalASIPMeta.txt"
rm -f ${globalIPMeta}
for elem in `find ${meddleDecPcapData} -name "*.pcap*"`; 
do 
     python ${getIPFromFile} ${elem} 1 >> ${globalIPMeta}; 
done
uniq ${globalIPMeta} | sort | uniq > tmp.txt
echo "begin" > ${globalIPMeta}
echo "verbose" >> ${globalIPMeta}
cat tmp.txt >> ${globalIPMeta}
echo "end" >> ${globalIPMeta}

nc whois.cymru.com 43 < ${globalIPMeta} | sort -n | uniq  > tmp.txt 

echo "as ip_prefix country as_info issue_date isp_info" > ${globalIPAsMeta}
#AS network country as_info issue_date provider_info" > ${globalIPAsMeta}
awk -F "|" '{print $1 " " $3 " " $4 " " $5 " " $6 " " $7 " " $8 " " $9}' tmp.txt | sort | uniq >> ${globalIPAsMeta}
# Does not work on MAC http://stackoverflow.com/questions/5398395/how-can-i-insert-a-tab-character-with-sed-on-os-x
sed  "s/   */	/g" ${globalIPAsMeta} > tmp.txt
rm tmp.txt
# Remove trailing white space
sed "s/ $//g" tmp.txt > ${globalIPAsMeta}

