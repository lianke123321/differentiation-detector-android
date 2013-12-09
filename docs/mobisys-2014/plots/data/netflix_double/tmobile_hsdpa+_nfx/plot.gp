set style data lines
set title "Netflix HSDPA+ (cutoff threshold = 100)"
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
plot "connections/108.175.35.155.80-10.11.3.3.50183" using 1:($2/1e6) with lines lw 3 title "A", \
"connections/108.175.35.155.80-10.11.3.3.50187" using 1:($2/1e6) with lines lw 3 title "B", \
"connections/108.175.35.155.80-10.11.3.3.50188" using 1:($2/1e6) with lines lw 3 title "C", \
"connections/108.175.35.155.80-10.11.3.3.50192" using 1:($2/1e6) with lines lw 3 title "D", \
"connections/23.0.160.43.80-10.11.3.3.57123" using 1:($2/1e6) with lines lw 3 title "E"
