set style data lines
set title "YouTube (upload) (cutoff threshold = 100000)"
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
plot "connections/10.11.3.3.35168-173.194.76.117.443" using 1:($2/1e6) with lines title "13", \
"connections/10.11.3.3.37530-74.125.131.99.443" using 1:($2/1e6) with lines title "18", \
"connections/10.11.3.3.44063-50.19.241.96.443" using 1:($2/1e6) with lines title "5", \
"connections/10.11.3.3.44633-63.116.58.124.80" using 1:($2/1e6) with lines title "0", \
"connections/10.11.3.3.45512-108.160.165.141.443" using 1:($2/1e6) with lines title "2", \
"connections/10.11.3.3.51403-173.194.76.117.443" using 1:($2/1e6) with lines title "16", \
"connections/10.11.3.3.55686-50.19.241.96.443" using 1:($2/1e6) with lines title "6", \
"connections/10.11.3.3.57713-108.160.165.141.443" using 1:($2/1e6) with lines title "11", \
"connections/10.11.3.3.59024-50.19.241.96.443" using 1:($2/1e6) with lines title "7", \
"connections/108.160.165.141.443-10.11.3.3.45512" using 1:($2/1e6) with lines title "3", \
"connections/108.160.165.141.443-10.11.3.3.57713" using 1:($2/1e6) with lines title "12", \
"connections/173.194.76.117.443-10.11.3.3.35168" using 1:($2/1e6) with lines title "14", \
"connections/173.194.76.117.443-10.11.3.3.51403" using 1:($2/1e6) with lines title "17", \
"connections/50.19.241.96.443-10.11.3.3.44063" using 1:($2/1e6) with lines title "8", \
"connections/50.19.241.96.443-10.11.3.3.55686" using 1:($2/1e6) with lines title "9", \
"connections/50.19.241.96.443-10.11.3.3.59024" using 1:($2/1e6) with lines title "10", \
"connections/74.125.131.99.443-10.11.3.3.37530" using 1:($2/1e6) with lines title "19"
