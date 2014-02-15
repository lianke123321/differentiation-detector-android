set term postscript color eps enhanced "Helvetica" 24
set key out below
#set key off
#set size ratio 0.5
set style line 80 lt 0
set grid back linestyle 81
set border 3 back linestyle 80
set xlabel "Application"
set ylabel "Throughput (KBytes/s)"
set xtics nomirror
set xtics rotate
set ytics nomirror
set output "results.ps"

set style fill solid border -1

num_of_categories=2
set boxwidth 0.3/num_of_categories
dx=0.5/num_of_categories
offset=-0.1

plot 'results.txt' using ($0):2:xtic(1) title "Average (VPN)" linecolor rgb "#3CB0D6" with boxes, \
     ''                   using ($0):3 title "Standard Deviation (VPN)" linecolor rgb "#73DCFF" with boxes, \
     'results.txt' using ($0)+dx:4 title "Average (No VPN)" linecolor rgb "#00cc00" with boxes, \
     ''                   using ($0)+dx:5 title "Standard Deviation (No VPN)" linecolor rgb "#00ff00" with boxes
