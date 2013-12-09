../../../../plot/filterer/filter ../../text_pcaps/tmobile_hsdpa+_nfx.txt 100 "Netflix HSDPA+";
echo File: dissected_pcaps/tmobile_hsdpa+_nfx.pcap.TCP_10-11-3-3_50192_108-175-35-155_80.pcap >tmobile_hsdpa+_nfx.rtt.txt
tcptrace -lr dissected_pcaps/tmobile_hsdpa+_nfx.pcap.TCP_10-11-3-3_50192_108-175-35-155_80.pcap| awk '/RTT min/,/RTT stdev/' >>tmobile_hsdpa+_nfx.rtt.txt;
cat meta.txt >tmobile_hsdpa+_nfx.stats.txt;
tshark -qz io,stat,0.1 -r ../../../pcaps/tmobile_hsdpa+_nfx.pcap | ../../../../plot/xput/xput xput.txt >>tmobile_hsdpa+_nfx.stats.txt;
gnuplot xputplot.gp;
cat tmobile_hsdpa+_nfx.rtt.txt | ../../../../plot/rtt/rtt >>tmobile_hsdpa+_nfx.stats.txt;
rm -rf tmobile_hsdpa+_nfx.rtt.txt;
rm -rf meta.txt;
