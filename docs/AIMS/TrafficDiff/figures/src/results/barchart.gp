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
set xtics rotate by -45
set ytics nomirror
set xrange [0.5:7.5]
set output "results.ps"

set style fill solid border -1

num_of_categories=2
set boxwidth 0.3/num_of_categories
dx=0.5/num_of_categories
offset=-0.1

plot 'results.txt' using ($0+1):2:3:xtic(1) title "Average (VPN)" linecolor rgb "#ff0000" linetype 1 with boxerrorbars, \
     'results.txt' using ($0+1)+dx:4:5 title "Average (No VPN)" linecolor rgb "#00cc00" linetype 1 with boxerrorbars
