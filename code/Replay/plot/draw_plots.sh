#! /bin/sh

# Just clean the results.
if [ $# -eq 1 ]; then
    if [ $1 = "clean" ]; then
	rm -rf ../data/generated_plots
	rm -rf ../data/text_pcaps
	exit
    fi
fi


# Clean the results.
rm -rf ../data/generated_plots
rm -rf ../data/text_pcaps

mkdir ../data/generated_plots
mkdir ../data/text_pcaps

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

# For every pcap you find in data/pcaps
for f in `cd ../data/pcaps;ls *.pcap;cd ../../plot`
do
    # Filter out the name (strip the extention).
    name=`echo "$f" | cut -d'.' -f1`
    echo Processing $f...
    # Make the directory for the plot.
    mkdir ../data/generated_plots/$name
    mkdir ../data/generated_plots/$name/dissected_pcaps
    # Dump the pcap to plain text using tcpdump.
    tcpdump -nr ../data/pcaps/$f >../data/text_pcaps/$name.txt 2>/dev/null
    mono SplitCap.exe
    cd ../data/generated_plots/$name
    # Generate the script to draw the plot.
    echo ../../../plot/filterer/filter ../../text_pcaps/$name.txt `cat ../../confs/"$name"`\; >filterit.sh
    cd ../../../plot/splitcap/; mono ./SplitCap.exe -r ../../data/pcaps/$f -o ../../data/generated_plots/$name/dissected_pcaps/ >/dev/null  2>/dev/null; cd ../../data/generated_plots/$name/;
    echo echo File: `find dissected_pcaps/*.pcap -printf '%s %p\n'|sort -nr|head -n 1|awk '{print $2}'` \>$name.rtt.txt >>filterit.sh
    echo tcptrace -lr `find dissected_pcaps/*.pcap -printf '%s %p\n'|sort -nr|head -n 1|awk '{print $2}'`\| awk \'/RTT min/,/RTT stdev/\' \>\>$name.rtt.txt\; >>filterit.sh
    echo cat meta.txt \>$name.stats.txt\; >>filterit.sh
    echo tshark -qz io,stat,0.1 -r ../../pcaps/$f \| ../../../plot/xput/xput xput.txt \>\>$name.stats.txt\; >>filterit.sh
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
    echo convert -density 1000 xp.ps -scale 2000x1000 xp.jpg >>filterit.sh
    echo cat $name.rtt.txt \| ../../../plot/rtt/rtt \>\>$name.stats.txt\; >>filterit.sh
    echo rm -rf $name.rtt.txt\; >>filterit.sh
    echo rm -rf meta.txt\; >>filterit.sh
    chmod +x filterit.sh
    # Run the script.
    ./filterit.sh
    # Go back.
    cd ../../../plot
    echo Done.
done
