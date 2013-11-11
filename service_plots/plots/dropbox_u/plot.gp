set style data lines
set title "Drobpox Upload (14 MB file) (cutoff threshold = 100)"
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
plot "connections/10.11.3.3.37215-54.243.139.204.443" using 1:($2/1e6) with lines lw 3 title "A"
