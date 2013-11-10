set style data lines
set title "Drobpox Upload (14 MB file) (cutoff threshold = 100000)"
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
plot "connections/10.11.3.3.37215-54.243.139.204.443" using 1:($2/1e6) with lines title "16", \
"connections/10.11.3.3.38506-108.160.165.14.443" using 1:($2/1e6) with lines title "8", \
"connections/10.11.3.3.42653-74.125.29.95.443" using 1:($2/1e6) with lines title "12", \
"connections/10.11.3.3.45280-108.160.165.14.443" using 1:($2/1e6) with lines title "3", \
"connections/10.11.3.3.48204-108.160.165.14.443" using 1:($2/1e6) with lines title "4", \
"connections/10.11.3.3.49325-108.160.165.14.443" using 1:($2/1e6) with lines title "2", \
"connections/10.11.3.3.55131-108.160.165.14.443" using 1:($2/1e6) with lines title "0", \
"connections/10.11.3.3.55163-108.160.166.14.443" using 1:($2/1e6) with lines title "20", \
"connections/10.11.3.3.57911-108.160.166.14.443" using 1:($2/1e6) with lines title "14", \
"connections/10.11.3.3.60361-108.160.166.14.443" using 1:($2/1e6) with lines title "18", \
"connections/10.11.3.3.60949-54.243.139.204.443" using 1:($2/1e6) with lines title "10", \
"connections/108.160.165.14.443-10.11.3.3.38506" using 1:($2/1e6) with lines title "9", \
"connections/108.160.165.14.443-10.11.3.3.45280" using 1:($2/1e6) with lines title "5", \
"connections/108.160.165.14.443-10.11.3.3.48204" using 1:($2/1e6) with lines title "7", \
"connections/108.160.165.14.443-10.11.3.3.49325" using 1:($2/1e6) with lines title "6", \
"connections/108.160.165.14.443-10.11.3.3.55131" using 1:($2/1e6) with lines title "1", \
"connections/108.160.166.14.443-10.11.3.3.55163" using 1:($2/1e6) with lines title "21", \
"connections/108.160.166.14.443-10.11.3.3.57911" using 1:($2/1e6) with lines title "15", \
"connections/108.160.166.14.443-10.11.3.3.60361" using 1:($2/1e6) with lines title "19", \
"connections/54.243.139.204.443-10.11.3.3.37215" using 1:($2/1e6) with lines title "17", \
"connections/54.243.139.204.443-10.11.3.3.60949" using 1:($2/1e6) with lines title "11", \
"connections/74.125.29.95.443-10.11.3.3.42653" using 1:($2/1e6) with lines title "13"
