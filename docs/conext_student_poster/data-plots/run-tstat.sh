folder=$1
if [ ${folder} == "" ];
then
        exit
fi
cnt=0
tmpFile="tmp.pcap"
for elem in `find ${folder} -name "tcpdump-*"`;
do
        if [ -s ${elem} ] ;
        then
                echo ${numPkts}
                cp ${elem} ${tmpFile}${cnt}
		tstat -strace-${folder} -Nnet.txt ${tmpFile}${cnt}
		rm -f ${tmpFile}${cnt}
                cnt=$((cnt+1))
        fi
done
