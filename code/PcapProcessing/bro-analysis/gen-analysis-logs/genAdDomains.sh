namedconfadblock="./named.conf.adblock"
adDomainFile="/Users/ashwin/proj-work/meddle/meddle-data/bro-aggregate-data/adDomain.txt"
echo domain > ${adDomainFile}
awk '{print $2}' ${namedconfadblock} | grep \" | sed 's/\"//g' >> ${adDomainFile}
