fName=${1}

awk '{print $5 " " $9}' ${fName} | cut -d '-' -f 1,12 | sed 's/tcpdump-//g' - | sed 's/\.pcap\.enc//g' | awk '{print $2 " " $1}'  | sort -n 
