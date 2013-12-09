../../../../plot/filterer/filter ../../text_pcaps/university_nfx.txt 100 "Netflix University WiFi";
echo File: dissected_pcaps/university_nfx.pcap.TCP_10-11-3-3_48978_108-175-35-155_80.pcap >university_nfx.rtt.txt
tcptrace -lr dissected_pcaps/university_nfx.pcap.TCP_10-11-3-3_48978_108-175-35-155_80.pcap| awk '/RTT min/,/RTT stdev/' >>university_nfx.rtt.txt;
cat meta.txt >university_nfx.stats.txt;
tshark -qz io,stat,0.1 -r ../../../pcaps/university_nfx.pcap | ../../../../plot/xput/xput xput.txt >>university_nfx.stats.txt;
gnuplot xputplot.gp;
cat university_nfx.rtt.txt | ../../../../plot/rtt/rtt >>university_nfx.stats.txt;
rm -rf university_nfx.rtt.txt;
rm -rf meta.txt;
