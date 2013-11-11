set style data lines
set title "Torrent (cutoff threshold = 100)"
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
plot "connections/188.130.133.200.51413-10.11.3.3.6881_UDP" using 1:($2/1e6) with lines lw 3 title "A(UDP)", \
"connections/190.49.98.235.51413-10.11.3.3.6881_UDP" using 1:($2/1e6) with lines lw 3 title "B(UDP)", \
"connections/24.143.98.211.51413-10.11.3.3.34762" using 1:($2/1e6) with lines lw 3 title "C", \
"connections/37.59.39.125.55999-10.11.3.3.47596" using 1:($2/1e6) with lines lw 3 title "D", \
"connections/5.17.131.94.15244-10.11.3.3.6881_UDP" using 1:($2/1e6) with lines lw 3 title "E(UDP)", \
"connections/62.75.208.31.51413-10.11.3.3.59805" using 1:($2/1e6) with lines lw 3 title "F", \
"connections/65.49.70.244.55555-10.11.3.3.47084" using 1:($2/1e6) with lines lw 3 title "G", \
"connections/67.205.15.74.6955-10.11.3.3.44163" using 1:($2/1e6) with lines lw 3 title "H", \
"connections/79.227.188.17.51413-10.11.3.3.6881_UDP" using 1:($2/1e6) with lines lw 3 title "I(UDP)", \
"connections/79.50.246.40.25515-10.11.3.3.6881_UDP" using 1:($2/1e6) with lines lw 3 title "J(UDP)", \
"connections/95.154.93.4.51413-10.11.3.3.6881_UDP" using 1:($2/1e6) with lines lw 3 title "K(UDP)", \
"connections/95.190.4.130.51413-10.11.3.3.6881_UDP" using 1:($2/1e6) with lines lw 3 title "L(UDP)"
