set style data lines
set title "Drobpox Upload (26.1 MB file) (cutoff threshold = 100000)"
set key out right
set xlabel "Time (seconds)"
set ylabel "Cumulative Transfer (MB)"
set term postscript color eps enhanced "Helvetica" 8
set size ratio 0.5
# Line style for axes
set style line 80 lt 0
set grid back linestyle 81
set border 3 back linestyle 80
set xtics nomirror
set ytics nomirror
set out 'p.ps'
plot "connections/10.11.3.3.33332-74.125.29.95.443" using 1:($2/1e6) with lines title "17", \
"connections/10.11.3.3.43321-108.160.165.14.443" using 1:($2/1e6) with lines title "0", \
"connections/10.11.3.3.51871-54.225.210.211.443" using 1:($2/1e6) with lines title "11"
