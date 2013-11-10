set style data lines
set title "Drobpox Download (14 MB file) (cutoff threshold = 100000)"
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
plot "connections/10.11.3.3.51411-130.245.9.212.443" using 1:($2/1e6) with lines title "0", \
"connections/107.21.232.19.443-10.11.3.3.33117" using 1:($2/1e6) with lines title "8", \
"connections/107.21.232.19.443-10.11.3.3.47009" using 1:($2/1e6) with lines title "6"
