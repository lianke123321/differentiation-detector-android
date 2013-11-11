set style data lines
set title "Pandora (cutoff threshold = 10)"
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
plot "connections/184.51.126.65.80-10.11.3.3.44602" using 1:($2/1e6) with lines lw 3 title "A", \
"connections/208.85.42.22.80-10.11.3.3.41619" using 1:($2/1e6) with lines lw 3 title "B", \
"connections/208.85.44.21.80-10.11.3.3.44147" using 1:($2/1e6) with lines lw 3 title "C", \
"connections/208.85.46.21.80-10.11.3.3.40973" using 1:($2/1e6) with lines lw 3 title "D"
