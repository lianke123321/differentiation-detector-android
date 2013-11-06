PCAP_FILE='replay.pcap'

END=$(tshark -r $PCAP_FILE -T fields -e tcp.stream | sort -n | tail -1)
echo $END+1
for ((i=0;i<=END;i++))
do
    echo $i
    tshark -r $PCAP_FILE -qz follow,tcp,hex,$i > follow-stream-$i.txt
done
