set style data lines
set title "Pandora (cutoff threshold = 1000)"
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
plot "connections/10.11.3.3.41221-74.125.226.228.443" using 1:($2/1e6) with lines title "0", \
"connections/184.51.126.65.80-10.11.3.3.44602" using 1:($2/1e6) with lines title "73", \
"connections/205.251.243.65.80-10.11.3.3.53070" using 1:($2/1e6) with lines title "56", \
"connections/208.85.40.50.80-10.11.3.3.36558" using 1:($2/1e6) with lines title "19", \
"connections/208.85.40.92.443-10.11.3.3.47338" using 1:($2/1e6) with lines title "14", \
"connections/208.85.42.22.80-10.11.3.3.41619" using 1:($2/1e6) with lines title "48", \
"connections/208.85.42.31.80-10.11.3.3.56296" using 1:($2/1e6) with lines title "39", \
"connections/208.85.44.21.80-10.11.3.3.44147" using 1:($2/1e6) with lines title "127", \
"connections/208.85.46.21.80-10.11.3.3.40973" using 1:($2/1e6) with lines title "93", \
"connections/208.85.46.26.80-10.11.3.3.60021" using 1:($2/1e6) with lines title "120", \
"connections/54.230.101.82.80-10.11.3.3.60801" using 1:($2/1e6) with lines title "83", \
"connections/54.230.101.82.80-10.11.3.3.60805" using 1:($2/1e6) with lines title "95", \
"connections/54.230.103.61.80-10.11.3.3.59377" using 1:($2/1e6) with lines title "62"
