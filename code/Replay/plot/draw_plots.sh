#! /bin/bash

dir='pcaps'

if [ $# -gt 0 ]
then
    dir=$1
fi

sto='false'

if [ $# -gt 1 ]
then
    if [ "$2" = "-" ]
    then
	sto='true'
    fi
fi

# Clean the results.
if [ $sto != 'true' ]; then
rm -rf ../data/$dir/generated_plots
rm -rf ../data/$dir/text_pcaps

mkdir ../data/$dir/generated_plots
mkdir ../data/$dir/text_pcaps

echo Making the filterer...

cd filterer
make >/dev/null
cd ..

cd rtt
make >/dev/null
cd ..

cd xput
make >/dev/null
cd ..

echo Done.
fi

tput='0'
novpn_xput_max='0'
novpn_xput_avg='0'
novpn_xput_mdn='0'

novpn_loss_rate='0'

novpn_rtt_ab_min='0'
novpn_rtt_ba_min='0'
novpn_rtt_ab_max='0'
novpn_rtt_ba_max='0'
novpn_rtt_ab_avg='0'
novpn_rtt_ba_avg='0'
novpn_rtt_ab_stdev='0'
novpn_rtt_ba_stdev='0'

novpn_rtt_count='0'
novpn_count='0'

vpn_xput_max='0'
vpn_xput_avg='0'
vpn_xput_mdn='0'

vpn_loss_rate='0'

vpn_rtt_ab_min='0'
vpn_rtt_ba_min='0'
vpn_rtt_ab_max='0'
vpn_rtt_ba_max='0'
vpn_rtt_ab_avg='0'
vpn_rtt_ba_avg='0'
vpn_rtt_ab_stdev='0'
vpn_rtt_ba_stdev='0'

vpn_rtt_count='0'
vpn_count='0'

# For every pcap you find in data/pcaps
for f in `cd ../data/$dir;ls *.pcap;cd ../../../plot`
do
    # Filter out the name (strip the extention).
    name=${f%.pcap}
    echo Processing $f...
    if [ $sto != 'true' ]; then
    # Make the directory for the plot.
    mkdir "../data/$dir/generated_plots/$name"
    mkdir "../data/$dir/generated_plots/$name/dissected_pcaps"
    # Dump the pcap to plain text using tcpdump.
    tcpdump -nr ../data/$dir/$f >../data/$dir/text_pcaps/$name.txt 2>/dev/null
    mono SplitCap.exe
    cd "../data/$dir/generated_plots/$name"
    # Generate the script to draw the plot.
    echo ../../../../plot/filterer/filter ../../text_pcaps/$name.txt `cat ../../confs/"$name"`\; >filterit.sh
    cd ../../../../plot/splitcap/; mono ./SplitCap.exe -r ../../data/$dir/$f -o ../../data/$dir/generated_plots/$name/dissected_pcaps/ >/dev/null  2>/dev/null; cd ../../data/$dir/generated_plots/$name/;
    echo echo File: `find dissected_pcaps/*.pcap -printf '%s %p\n'|sort -nr|head -n 1|awk '{print $2}'` \>$name.rtt.txt >>filterit.sh
    echo tcptrace -lr `find dissected_pcaps/*.pcap -printf '%s %p\n'|sort -nr|head -n 1|awk '{print $2}'`\| awk \'/RTT min/,/RTT stdev/\' \>\>$name.rtt.txt\; >>filterit.sh
    echo cat meta.txt \>$name.stats.txt\; >>filterit.sh
    echo tshark -qz io,stat,0.1 -r ../../../$dir/$f \| ../../../../plot/xput/xput xput.txt \>\>$name.stats.txt\; >>filterit.sh
    echo 'set style data lines
set title "Throughput"
set key off
set xlabel "Time (seconds)"
set ylabel "Throughput (KB/s)"
set term postscript color eps enhanced "Helvetica" 16
set size ratio 0.5
# Line style for axes
set style line 80 lt 0
set grid back linestyle 81
set border 3 back linestyle 80
set xtics nomirror
set ytics nomirror
set out "xp.ps"
plot "xput.txt" using 1:($2/1e3) with lines lw 3' >xputplot.gp
    echo gnuplot xputplot.gp\; >>filterit.sh
#    echo convert -density 1000 xp.ps -scale 2000x1000 xp.jpg >>filterit.sh
    echo cat $name.rtt.txt \| ../../../../plot/rtt/rtt \>\>$name.stats.txt\; >>filterit.sh
    echo rm -rf $name.rtt.txt\; >>filterit.sh
    echo rm -rf meta.txt\; >>filterit.sh
    chmod +x filterit.sh
    # Run the script.
    ./filterit.sh
    fi

    if [ $sto = 'true' ]; then
	cd "../data/$dir/generated_plots/$name"     
    fi

    loss_rate=`cat $name.stats.txt | grep loss_rate | awk '{print $2}'`
    xput_max=`cat $name.stats.txt | grep xput_max | awk '{print $2}'`
    xput_avg=`cat $name.stats.txt | grep xput_avg | awk '{print $2}'`
    xput_mdn=`cat $name.stats.txt | grep xput_mdn | awk '{print $2}'`
    rtt_ab_min=`cat $name.stats.txt | grep rtt_ab_min | awk '{print $2}'`
    rtt_ba_min=`cat $name.stats.txt | grep rtt_ba_min | awk '{print $2}'`
    rtt_ab_max=`cat $name.stats.txt | grep rtt_ab_max | awk '{print $2}'`
    rtt_ba_max=`cat $name.stats.txt | grep rtt_ba_max | awk '{print $2}'`
    rtt_ab_avg=`cat $name.stats.txt | grep rtt_ab_avg | awk '{print $2}'`
    rtt_ba_avg=`cat $name.stats.txt | grep rtt_ba_avg | awk '{print $2}'`
    rtt_ab_stdev=`cat $name.stats.txt | grep rtt_ab_stdev | awk '{print $2}'`
    rtt_ba_stdev=`cat $name.stats.txt | grep rtt_ba_stdev | awk '{print $2}'`

    if [[ $name == dump_novpn* ]]
    then
	novpn_loss_rate=`bc -l <<< "$novpn_loss_rate + $loss_rate"`
	novpn_xput_max=`bc -l <<< "$novpn_xput_max + $xput_max"`
	novpn_xput_avg=`bc -l <<< "$novpn_xput_avg + $xput_avg"`
	novpn_xput_mdn=`bc -l <<< "$novpn_xput_mdn + $xput_mdn"`
	
	novpn_count=`bc -l <<< "$novpn_count + 1"`
	
	if [ $rtt_ab_min != '' ]
	then
	    novpn_rtt_ab_min=`bc -l <<< "$novpn_rtt_ab_min + $rtt_ab_min"`
	    novpn_rtt_ba_min=`bc -l <<< "$novpn_rtt_ba_min + $rtt_ba_min"`
	    novpn_rtt_ab_max=`bc -l <<< "$novpn_rtt_ab_max + $rtt_ab_max"`
	    novpn_rtt_ba_max=`bc -l <<< "$novpn_rtt_ba_max + $rtt_ba_max"`
	    novpn_rtt_ab_avg=`bc -l <<< "$novpn_rtt_ab_avg + $rtt_ab_avg"`
	    novpn_rtt_ba_avg=`bc -l <<< "$novpn_rtt_ba_avg + $rtt_ba_avg"`
	    novpn_rtt_ab_stdev=`bc -l <<< "$novpn_rtt_ab_stdev + $rtt_ab_stdev"`
	    novpn_rtt_ba_stdev=`bc -l <<< "$novpn_rtt_ba_stdev + $rtt_ba_stdev"`
	    
	    novpn_rtt_count=`bc -l <<< "$novpn_rtt_count + 1"`
	fi
    fi

    if [[ $name == tcpdump-* ]]
    then
	vpn_loss_rate=`bc -l <<< "$vpn_loss_rate + $loss_rate"`
	vpn_xput_max=`bc -l <<< "$vpn_xput_max + $xput_max"`
	vpn_xput_avg=`bc -l <<< "$vpn_xput_avg + $xput_avg"`
	vpn_xput_mdn=`bc -l <<< "$vpn_xput_mdn + $xput_mdn"`
	
	vpn_count=`bc -l <<< "$vpn_count + 1"`

	if [ $rtt_ab_min != '' ]
	then
	    vpn_rtt_ab_min=`bc -l <<< "$vpn_rtt_ab_min + $rtt_ab_min"`
	    vpn_rtt_ba_min=`bc -l <<< "$vpn_rtt_ba_min + $rtt_ba_min"`
	    vpn_rtt_ab_max=`bc -l <<< "$vpn_rtt_ab_max + $rtt_ab_max"`
	    vpn_rtt_ba_max=`bc -l <<< "$vpn_rtt_ba_max + $rtt_ba_max"`
	    vpn_rtt_ab_avg=`bc -l <<< "$vpn_rtt_ab_avg + $rtt_ab_avg"`
	    vpn_rtt_ba_avg=`bc -l <<< "$vpn_rtt_ba_avg + $rtt_ba_avg"`
	    vpn_rtt_ab_stdev=`bc -l <<< "$vpn_rtt_ab_stdev + $rtt_ab_stdev"`
	    vpn_rtt_ba_stdev=`bc -l <<< "$vpn_rtt_ba_stdev + $rtt_ba_stdev"`
	    
	    vpn_rtt_count=`bc -l <<< "$vpn_rtt_count + 1"`
	fi
    fi

    # Go back.
    cd ../../../../plot
    echo Done.
done
echo Mean of maximum throughput for the non-encrypted is: `bc -l <<< "$novpn_xput_max / $novpn_count"` KB/s
echo Mean of average throughput for the non-encrypted is: `bc -l <<< "$novpn_xput_avg / $novpn_count"` KB/s
echo Mean of median throughput for the non-encrypted is: `bc -l <<< "$novpn_xput_mdn / $novpn_count"` KB/s
echo Mean of loss rate for the non-encrypted is: `bc -l <<< "$novpn_loss_rate / $novpn_count"` \%

echo Mean of maximum throughput for the encrypted is: `bc -l <<< "$vpn_xput_max / $vpn_count"` KB/s
echo Mean of average throughput for the encrypted is: `bc -l <<< "$vpn_xput_avg / $vpn_count"` KB/s
echo Mean of median throughput for the encrypted is: `bc -l <<< "$vpn_xput_mdn / $vpn_count"` KB/s
echo Mean of loss rate for the encrypted is: `bc -l <<< "$vpn_loss_rate / $vpn_count"` \%

echo unencrypted_xput_max: `bc -l <<< "$novpn_xput_max / $novpn_count"` >../data/$dir.stats.txt
echo unencrypted_xput_avg: `bc -l <<< "$novpn_xput_avg / $novpn_count"` >>../data/$dir.stats.txt
echo unencrypted_xput_mdn: `bc -l <<< "$novpn_xput_mdn / $novpn_count"` >>../data/$dir.stats.txt
echo unencrypted_loss_rate: `bc -l <<< "$novpn_loss_rate / $novpn_count"` >>../data/$dir.stats.txt
echo unencrypted_rtt_ab_min: `bc -l <<< "$novpn_rtt_ab_min / $novpn_rtt_count"` >>../data/$dir.stats.txt
echo unencrypted_rtt_ba_min: `bc -l <<< "$novpn_rtt_ba_min / $novpn_rtt_count"` >>../data/$dir.stats.txt
echo unencrypted_rtt_ab_max: `bc -l <<< "$novpn_rtt_ab_max / $novpn_rtt_count"` >>../data/$dir.stats.txt
echo unencrypted_rtt_ba_max: `bc -l <<< "$novpn_rtt_ba_max / $novpn_rtt_count"` >>../data/$dir.stats.txt
echo unencrypted_rtt_ab_avg: `bc -l <<< "$novpn_rtt_ab_avg / $novpn_rtt_count"` >>../data/$dir.stats.txt
echo unencrypted_rtt_ba_avg: `bc -l <<< "$novpn_rtt_ba_avg / $novpn_rtt_count"` >>../data/$dir.stats.txt
echo unencrypted_rtt_ab_stdev: `bc -l <<< "$novpn_rtt_ab_stdev / $novpn_rtt_count"` >>../data/$dir.stats.txt
echo unencrypted_rtt_ba_stdev: `bc -l <<< "$novpn_rtt_ba_stdev / $novpn_rtt_count"` >>../data/$dir.stats.txt

echo encrypted_xput_max: `bc -l <<< "$vpn_xput_max / $vpn_count"` >>../data/$dir.stats.txt
echo encrypted_xput_avg: `bc -l <<< "$vpn_xput_avg / $vpn_count"` >>../data/$dir.stats.txt
echo encrypted_xput_mdn: `bc -l <<< "$vpn_xput_mdn / $vpn_count"` >>../data/$dir.stats.txt
echo encrypted_loss_rate: `bc -l <<< "$vpn_loss_rate / $vpn_count"` >>../data/$dir.stats.txt
echo encrypted_rtt_ab_min: `bc -l <<< "$vpn_rtt_ab_min / $vpn_rtt_count"` >>../data/$dir.stats.txt
echo encrypted_rtt_ba_min: `bc -l <<< "$vpn_rtt_ba_min / $vpn_rtt_count"` >>../data/$dir.stats.txt
echo encrypted_rtt_ab_max: `bc -l <<< "$vpn_rtt_ab_max / $vpn_rtt_count"` >>../data/$dir.stats.txt
echo encrypted_rtt_ba_max: `bc -l <<< "$vpn_rtt_ba_max / $vpn_rtt_count"` >>../data/$dir.stats.txt
echo encrypted_rtt_ab_avg: `bc -l <<< "$vpn_rtt_ab_avg / $vpn_rtt_count"` >>../data/$dir.stats.txt
echo encrypted_rtt_ba_avg: `bc -l <<< "$vpn_rtt_ba_avg / $vpn_rtt_count"` >>../data/$dir.stats.txt
echo encrypted_rtt_ab_stdev: `bc -l <<< "$vpn_rtt_ab_stdev / $vpn_rtt_count"` >>../data/$dir.stats.txt
echo encrypted_rtt_ba_stdev: `bc -l <<< "$vpn_rtt_ba_stdev / $vpn_rtt_count"` >>../data/$dir.stats.txt
