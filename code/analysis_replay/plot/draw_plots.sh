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

rm -rf ../data/$dir/results/

mkdir ../data/$dir/results/

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

cd ten_ninety
make >/dev/null
cd ..

echo Done.
fi

tput='0'
novpn_xput_max='0'
novpn_xput_avg='0'
novpn_xput_mdn='0'

novpn_loss_rate='0'
novpn_loss_rate2='0'

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
vpn_loss_rate2='0'

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
for f in `cd ../data/$dir;ls *.pcap;cd ../../plot`
do
    # Filter out the name (strip the extention).
    name=${f%.pcap}
    echo Processing $f...
    if [ $sto != 'true' ]; then
    # Make the directory for the plot.
    mkdir "../data/$dir/generated_plots/$name"
    # mkdir "../data/$dir/generated_plots/$name/dissected_pcaps"
    # Dump the pcap to plain text using tcpdump.
    tcpdump -nr ../data/$dir/$f >../data/$dir/text_pcaps/$name.txt 2>/dev/null
    cd "../data/$dir/generated_plots/$name"
    # Generate the script to draw the plot.
    if [ -b ../../confs/$name ]; then
	conf=`cat ../../confs/"$name"`
    else
	conf=''
    fi;
    echo ../../../../plot/filterer/filter ../../text_pcaps/$name.txt $conf\; >filterit.sh
    # SplitCap.exe was used to split the pcap into streams (UDP and TCP).
    # cd ../../../../plot/splitcap/; mono ./SplitCap.exe -r ../../data/$dir/$f -o ../../data/$dir/generated_plots/$name/dissected_pcaps/ >/dev/null  2>/dev/null; cd ../../data/$dir/generated_plots/$name/;

# ******************************
# Calculating RTT using tcptrace
# ******************************

    # Split the PCAP into streams using tshark filters.
    # Note that this will only extract streams that are deemed "big enough by the filterer (the ones that appear in the plot).
#    echo "for flow in \`cat connection_index.txt | awk '{print \$3}';\`
#    do
#        if [ \${flow%_UDP} = \$flow ];
#        then
#	    proto=tcp
#        else
#	    proto=udp
#	fi;
#        f=\${flow%_UDP}
#
#        src=\`echo \$f | cut -d \- -f 1 | cut -d \. -f 5 --complement\`
#	dst=\`echo \$f | cut -d \- -f 2 | cut -d \. -f 5 --complement\`
#
#	src_port=\`echo \$f | cut -d \- -f 1 | cut -d \. -f 5\`
#	dst_port=\`echo \$f | cut -d \- -f 2 | cut -d \. -f 5\`
#
#        tshark -r ../../$f -2 -w dissected_pcaps/\$f-\$proto.pcap -R \"ip.src==\$src and \$proto.srcport==\$src_port and ip.dst==\$dst and \$proto.dstport==\$dst_port\"
#    done;" >> filterit.sh

    # This can be used in place of SplitCap .NET tool, but it only treats TCP streams and ignores UDP.
    #for stream in `tshark -r ../../$f -T fields -e tcp.stream | sort -n | uniq`
    #do
	#echo $stream
	#tshark -r ../../$f -2 -w dissected_pcaps/stream-$stream.pcap -R "tcp.stream==$stream"
    #done
    

#    echo echo File: \`find dissected_pcaps/*.pcap -printf \'%s %p\\n\'\|sort -nr\|head -n 1\|awk \'{print \$2}\'\` \>$name.rtt.txt\; >>filterit.sh
#    echo tcptrace -lr \`find dissected_pcaps/*.pcap -printf \'%s %p\\n\'\|sort -nr\|head -n 1\|awk \'{print \$2}\'\` \| awk \'/RTT min/,/RTT stdev/\' \>\>$name.rtt.txt\; >>filterit.sh


#    mkdir rtts
#    echo cd rtts >>filterit.sh
#    echo tcptrace -Z ../../../$f \>/dev/null \; >>filterit.sh
#    echo cat *_rttraw.dat \| grep -v " 0" \| sort -n -k2,2 \| awk \'{print \$2}\' \>rtts.txt >>filterit.sh
#    echo cd .. >>filterit.sh

# ******************************
#              END
# ******************************


    echo gnuplot cdfrtt.gp\; >>filterit.sh

    echo 'set title "RTT CDF"
set style data lines
set key bottom right
set ylabel "CDF"
set xlabel "RTT"
set yrange [0:1]
set term postscript color eps enhanced "Helvetica" 16
set size ratio 0.5
# Line style for axes
set style line 80 lt 0
set grid back linestyle 81
set border 3 back linestyle 80
set xtics nomirror
set ytics nomirror
set out "cdfrttp.ps"
a=0
cumulative_sum(x)=(a=a+x,a)
countpoints(file) = system( sprintf("grep -v \"^#\" %s| wc -l", file) )
pointcount = countpoints("rtt_samples.txt")
plot "rtt_samples.txt" using 1:(1.0/pointcount) smooth cumulative with lines lw 3 linecolor rgb "green" t "A to B"' >cdfrtt.gp

    echo cat meta.txt \>$name.stats.txt\; >>filterit.sh
    echo tshark -qz io,stat,0.1 -r ../../../$dir/$f \| ../../../../plot/xput/xput xput.txt n \>\>$name.stats.txt\; >>filterit.sh
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
plot "xput.txt" using 1:($2/1000.0) with lines lw 3' >xputplot.gp
    echo gnuplot xputplot.gp\; >>filterit.sh
    echo cat xput.txt \| sort -n -k2,2 \| awk \'{print \$2}\' \>xpsorted.txt >>filterit.sh
    echo 'set style data lines
set title "Throughput CDF"
set key off
set xlabel "Throughput (KB/s)"
set ylabel "CDF"
set yrange [0:1]
set term postscript color eps enhanced "Helvetica" 16
set size ratio 0.5
# Line style for axes
set style line 80 lt 0
set grid back linestyle 81
set border 3 back linestyle 80
set xtics nomirror
set ytics nomirror
set out "xpcdf.ps"
countpoints(file) = system( sprintf("grep -v \"^#\" %s| wc -l", file) )
pointcount = countpoints("xpsorted.txt")
plot "xpsorted.txt" using ($1/1000.0):(1.0/pointcount) smooth cumulative with lines lw 3 linecolor rgb "blue" t "A to B"' >xputcdf.gp
    echo gnuplot xputcdf.gp\; >>filterit.sh
#    echo convert -density 1000 -flatten xp.ps -scale 2000x1000 xp.jpg >>filterit.sh
#    echo cat $name.rtt.txt \| ../../../../plot/rtt/rtt \>\>$name.stats.txt\; >>filterit.sh

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

	if [[ $rtt_ab_min != '' ]]
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

if [ $vpn_count -ge 1 -a $novpn_count -ge 1 ]
then

cat ../data/$dir/generated_plots/dump_novpn*/rtts/rtts.txt | awk '{if ($1 > 10) print $1}' | sort -n >../data/$dir/results/$dir.rtts.novpn.txt
cat ../data/$dir/generated_plots/tcpdump*/rtts/rtts.txt | awk '{if ($1 > 10) print $1}' | sort -n >../data/$dir/results/$dir.rtts.vpn.txt

cat ../data/$dir/generated_plots/dump_novpn*/xpsorted.txt | sort -n >../data/$dir/results/$dir.xputs.novpn.txt
cat ../data/$dir/generated_plots/tcpdump*/xpsorted.txt | sort -n >../data/$dir/results/$dir.xputs.vpn.txt

echo 'set title "RTT CDF"
set style data lines
set key bottom right
set ylabel "CDF"
set xlabel "RTT"
set yrange [0:1]
set term postscript color eps enhanced "Helvetica" 16
set size ratio 0.5
# Line style for axes
set style line 80 lt 0
set grid back linestyle 81
set border 3 back linestyle 80
set xtics nomirror
set ytics nomirror
set out "'$dir'.cdfrttp.ps"
a=0
cumulative_sum(x)=(a=a+x,a)
countpoints(file) = system( sprintf("grep -v \"^#\" %s| wc -l", file) )
pointcountvpn = countpoints("'$dir'.rtts.vpn.txt")
pointcountnovpn = countpoints("'$dir'.rtts.novpn.txt")
plot "'$dir'.rtts.vpn.txt" using 1:(1.0/pointcountvpn) smooth cumulative with lines lw 3 linecolor rgb "green" t "With VPN",\
     "'$dir'.rtts.novpn.txt" using 1:(1.0/pointcountnovpn) smooth cumulative with lines lw 3 linecolor rgb "green" t "Without VPN"' >../data/$dir/results/$dir.rtts.cdf.gp

echo 'set title "Throughput CDF"
set style data lines
set key bottom right
set ylabel "CDF"
set xlabel "Throughput (KB/s)"
set yrange [0:1]
set term postscript color eps enhanced "Helvetica" 16
set size ratio 0.5
# Line style for axes
set style line 80 lt 0
set grid back linestyle 81
set border 3 back linestyle 80
set xtics nomirror
set ytics nomirror
set out "'$dir'.cdfxputp.ps"
a=0
cumulative_sum(x)=(a=a+x,a)
countpoints(file) = system( sprintf("grep -v \"^#\" %s| wc -l", file) )
pointcountvpn = countpoints("'$dir'.xputs.vpn.txt")
pointcountnovpn = countpoints("'$dir'.xputs.novpn.txt")
plot "'$dir'.xputs.vpn.txt" using ($1/1000.0):(1.0/pointcountvpn) smooth cumulative with lines lw 3 linecolor rgb "blue" t "With VPN",\
     "'$dir'.xputs.novpn.txt" using ($1/1000.0):(1.0/pointcountnovpn) smooth cumulative with lines lw 3 linecolor rgb "blue" t "Without VPN"' >../data/$dir/results/$dir.xputs.cdf.gp

cd ../data/$dir/results
gnuplot $dir.rtts.cdf.gp
gnuplot $dir.xputs.cdf.gp
../../../plot/ten_ninety/tn <$dir.rtts.vpn.txt >$dir.rtt.avg_stdev.vpn.txt
../../../plot/ten_ninety/tn <$dir.rtts.novpn.txt >$dir.rtt.avg_stdev.novpn.txt
cd ../../../plot


echo Mean of maximum throughput for the non-encrypted is: `bc -l <<< "$novpn_xput_max / $novpn_count"` KB/s
echo Mean of average throughput for the non-encrypted is: `bc -l <<< "$novpn_xput_avg / $novpn_count"` KB/s
echo Mean of median throughput for the non-encrypted is: `bc -l <<< "$novpn_xput_mdn / $novpn_count"` KB/s
echo Mean of loss rate for the non-encrypted is: `bc -l <<< "$novpn_loss_rate / $novpn_count"` \%

echo Mean of maximum throughput for the encrypted is: `bc -l <<< "$vpn_xput_max / $vpn_count"` KB/s
echo Mean of average throughput for the encrypted is: `bc -l <<< "$vpn_xput_avg / $vpn_count"` KB/s
echo Mean of median throughput for the encrypted is: `bc -l <<< "$vpn_xput_mdn / $vpn_count"` KB/s
echo Mean of loss rate for the encrypted is: `bc -l <<< "$vpn_loss_rate / $vpn_count"` \%

echo unencrypted_xput_max: `bc -l <<< "$novpn_xput_max / $novpn_count"` >../data/$dir/results/$dir.stats.txt
echo unencrypted_xput_avg: `bc -l <<< "$novpn_xput_avg / $novpn_count"` >>../data/$dir/results/$dir.stats.txt
echo unencrypted_xput_mdn: `bc -l <<< "$novpn_xput_mdn / $novpn_count"` >>../data/$dir/results/$dir.stats.txt
echo unencrypted_loss_rate: `bc -l <<< "$novpn_loss_rate / $novpn_count"` >>../data/$dir/results/$dir.stats.txt
echo unencrypted_rtt_ab_min: `bc -l <<< "$novpn_rtt_ab_min / $novpn_rtt_count"` >>../data/$dir/results/$dir.stats.txt
echo unencrypted_rtt_ba_min: `bc -l <<< "$novpn_rtt_ba_min / $novpn_rtt_count"` >>../data/$dir/results/$dir.stats.txt
echo unencrypted_rtt_ab_max: `bc -l <<< "$novpn_rtt_ab_max / $novpn_rtt_count"` >>../data/$dir/results/$dir.stats.txt
echo unencrypted_rtt_ba_max: `bc -l <<< "$novpn_rtt_ba_max / $novpn_rtt_count"` >>../data/$dir/results/$dir.stats.txt
echo unencrypted_rtt_ab_avg: `bc -l <<< "$novpn_rtt_ab_avg / $novpn_rtt_count"` >>../data/$dir/results/$dir.stats.txt
echo unencrypted_rtt_ba_avg: `bc -l <<< "$novpn_rtt_ba_avg / $novpn_rtt_count"` >>../data/$dir/results/$dir.stats.txt
echo unencrypted_rtt_ab_stdev: `bc -l <<< "$novpn_rtt_ab_stdev / $novpn_rtt_count"` >>../data/$dir/results/$dir.stats.txt
echo unencrypted_rtt_ba_stdev: `bc -l <<< "$novpn_rtt_ba_stdev / $novpn_rtt_count"` >>../data/$dir/results/$dir.stats.txt

echo encrypted_xput_max: `bc -l <<< "$vpn_xput_max / $vpn_count"` >>../data/$dir/results/$dir.stats.txt
echo encrypted_xput_avg: `bc -l <<< "$vpn_xput_avg / $vpn_count"` >>../data/$dir/results/$dir.stats.txt
echo encrypted_xput_mdn: `bc -l <<< "$vpn_xput_mdn / $vpn_count"` >>../data/$dir/results/$dir.stats.txt
echo encrypted_loss_rate: `bc -l <<< "$vpn_loss_rate / $vpn_count"` >>../data/$dir/results/$dir.stats.txt
echo encrypted_rtt_ab_min: `bc -l <<< "$vpn_rtt_ab_min / $vpn_rtt_count"` >>../data/$dir/results/$dir.stats.txt
echo encrypted_rtt_ba_min: `bc -l <<< "$vpn_rtt_ba_min / $vpn_rtt_count"` >>../data/$dir/results/$dir.stats.txt
echo encrypted_rtt_ab_max: `bc -l <<< "$vpn_rtt_ab_max / $vpn_rtt_count"` >>../data/$dir/results/$dir.stats.txt
echo encrypted_rtt_ba_max: `bc -l <<< "$vpn_rtt_ba_max / $vpn_rtt_count"` >>../data/$dir/results/$dir.stats.txt
echo encrypted_rtt_ab_avg: `bc -l <<< "$vpn_rtt_ab_avg / $vpn_rtt_count"` >>../data/$dir/results/$dir.stats.txt
echo encrypted_rtt_ba_avg: `bc -l <<< "$vpn_rtt_ba_avg / $vpn_rtt_count"` >>../data/$dir/results/$dir.stats.txt
echo encrypted_rtt_ab_stdev: `bc -l <<< "$vpn_rtt_ab_stdev / $vpn_rtt_count"` >>../data/$dir/results/$dir.stats.txt
echo encrypted_rtt_ba_stdev: `bc -l <<< "$vpn_rtt_ba_stdev / $vpn_rtt_count"` >>../data/$dir/results/$dir.stats.txt

fi;