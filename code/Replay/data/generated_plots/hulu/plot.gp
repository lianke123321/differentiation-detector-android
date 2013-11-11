set style data lines
set title "Hulu (cutoff threshold = 100)"
set key out right
set xlabel "Time (seconds)"
set ylabel "Cumulative Transfer (MB)"
set term postscript color eps enhanced "Helvetica" 16
set size ratio 0.5
# Line style for axes
set style line 80 lt 0
set grid back linestyle 81
set border 3 back linestyle 80
set xtics nomirror
set ytics nomirror
set out 'p.ps'
plot "connections/23.0.160.40.80-10.11.3.3.39488" using 1:($2/1e6) with lines lw 3 title "A", \
"connections/23.0.160.42.80-10.11.3.3.43620" using 1:($2/1e6) with lines lw 3 title "B", \
"connections/23.0.160.42.80-10.11.3.3.49165" using 1:($2/1e6) with lines lw 3 title "C", \
"connections/23.0.160.42.80-10.11.3.3.54046" using 1:($2/1e6) with lines lw 3 title "D", \
"connections/23.0.160.42.80-10.11.3.3.55315" using 1:($2/1e6) with lines lw 3 title "E", \
"connections/23.0.160.80.80-10.11.3.3.51675" using 1:($2/1e6) with lines lw 3 title "F", \
"connections/23.0.160.80.80-10.11.3.3.51676" using 1:($2/1e6) with lines lw 3 title "G"
