set style data lines
set title "Hulu (cutoff threshold = 1000)"
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
plot "connections/10.11.3.3.40616-69.31.16.146.80" using 1:($2/1e6) with lines title "25", \
"connections/10.11.3.3.45904-173.252.112.23.443" using 1:($2/1e6) with lines title "80", \
"connections/173.252.112.23.443-10.11.3.3.45904" using 1:($2/1e6) with lines title "81", \
"connections/208.91.159.108.80-10.11.3.3.41496" using 1:($2/1e6) with lines title "42", \
"connections/208.91.159.108.80-10.11.3.3.48278" using 1:($2/1e6) with lines title "48", \
"connections/208.91.159.108.80-10.11.3.3.52018" using 1:($2/1e6) with lines title "45", \
"connections/23.0.160.40.80-10.11.3.3.39488" using 1:($2/1e6) with lines title "73", \
"connections/23.0.160.42.80-10.11.3.3.43620" using 1:($2/1e6) with lines title "40", \
"connections/23.0.160.42.80-10.11.3.3.49165" using 1:($2/1e6) with lines title "35", \
"connections/23.0.160.42.80-10.11.3.3.54046" using 1:($2/1e6) with lines title "37", \
"connections/23.0.160.42.80-10.11.3.3.55315" using 1:($2/1e6) with lines title "52", \
"connections/23.0.160.72.80-10.11.3.3.33580" using 1:($2/1e6) with lines title "50", \
"connections/23.0.160.72.80-10.11.3.3.44838" using 1:($2/1e6) with lines title "31", \
"connections/23.0.160.80.80-10.11.3.3.51675" using 1:($2/1e6) with lines title "66", \
"connections/23.0.160.80.80-10.11.3.3.51676" using 1:($2/1e6) with lines title "68", \
"connections/69.31.16.130.80-10.11.3.3.40991" using 1:($2/1e6) with lines title "15", \
"connections/69.31.16.146.80-10.11.3.3.40616" using 1:($2/1e6) with lines title "26"
