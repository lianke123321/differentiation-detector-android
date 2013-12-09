set style data lines
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
plot "xput.txt" using 1:($2/1e3) with lines lw 3
