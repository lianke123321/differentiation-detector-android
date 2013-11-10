set style data lines
set title "Torrent (cutoff threshold = 10000)"
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
plot "connections/10.11.3.3.32920-130.245.9.212.443" using 1:($2/1e6) with lines title "132", \
"connections/10.11.3.3.34658-91.121.199.227.55999" using 1:($2/1e6) with lines title "550", \
"connections/10.11.3.3.34762-24.143.98.211.51413" using 1:($2/1e6) with lines title "120", \
"connections/10.11.3.3.35331-87.153.205.25.5020" using 1:($2/1e6) with lines title "552", \
"connections/10.11.3.3.35852-94.23.14.83.55998" using 1:($2/1e6) with lines title "576", \
"connections/10.11.3.3.37212-79.242.94.56.22120" using 1:($2/1e6) with lines title "271", \
"connections/10.11.3.3.40370-63.116.58.124.80" using 1:($2/1e6) with lines title "471", \
"connections/10.11.3.3.42652-79.50.246.40.25515" using 1:($2/1e6) with lines title "626", \
"connections/10.11.3.3.43651-80.71.129.116.58303" using 1:($2/1e6) with lines title "506", \
"connections/10.11.3.3.44163-67.205.15.74.6955" using 1:($2/1e6) with lines title "168", \
"connections/10.11.3.3.45555-84.2.125.223.2200" using 1:($2/1e6) with lines title "462", \
"connections/10.11.3.3.45822-77.66.138.97.6890" using 1:($2/1e6) with lines title "187", \
"connections/10.11.3.3.46635-188.130.133.200.51413" using 1:($2/1e6) with lines title "257", \
"connections/10.11.3.3.47084-65.49.70.244.55555" using 1:($2/1e6) with lines title "145", \
"connections/10.11.3.3.47596-37.59.39.125.55999" using 1:($2/1e6) with lines title "121", \
"connections/10.11.3.3.53154-62.210.236.100.12000" using 1:($2/1e6) with lines title "147", \
"connections/10.11.3.3.55688-54.225.240.28.443" using 1:($2/1e6) with lines title "721", \
"connections/10.11.3.3.56462-188.32.35.138.51413" using 1:($2/1e6) with lines title "463", \
"connections/10.11.3.3.59327-79.47.75.14.39144" using 1:($2/1e6) with lines title "584", \
"connections/10.11.3.3.59805-62.75.208.31.51413" using 1:($2/1e6) with lines title "148", \
"connections/101.98.165.43.14644-10.11.3.3.6881_UDP" using 1:($2/1e6) with lines title "195(UDP)", \
"connections/14.33.30.113.52664-10.11.3.3.6881_UDP" using 1:($2/1e6) with lines title "188(UDP)", \
"connections/173.194.68.188.5228-10.11.3.3.35027" using 1:($2/1e6) with lines title "2", \
"connections/188.223.110.216.43925-10.11.3.3.6881_UDP" using 1:($2/1e6) with lines title "123(UDP)", \
"connections/188.32.35.138.51413-10.11.3.3.56462" using 1:($2/1e6) with lines title "478", \
"connections/217.114.229.43.63671-10.11.3.3.6881_UDP" using 1:($2/1e6) with lines title "411(UDP)", \
"connections/24.143.98.211.51413-10.11.3.3.34762" using 1:($2/1e6) with lines title "136", \
"connections/37.59.39.125.55999-10.11.3.3.47596" using 1:($2/1e6) with lines title "128", \
"connections/5.17.131.94.15244-10.11.3.3.54543" using 1:($2/1e6) with lines title "135", \
"connections/54.225.240.28.443-10.11.3.3.55688" using 1:($2/1e6) with lines title "722", \
"connections/62.75.208.31.51413-10.11.3.3.59805" using 1:($2/1e6) with lines title "153", \
"connections/65.49.70.244.55555-10.11.3.3.47084" using 1:($2/1e6) with lines title "150", \
"connections/67.205.15.74.6955-10.11.3.3.44163" using 1:($2/1e6) with lines title "171", \
"connections/77.66.138.97.6890-10.11.3.3.45822" using 1:($2/1e6) with lines title "192", \
"connections/79.227.188.17.51413-10.11.3.3.6881_UDP" using 1:($2/1e6) with lines title "575(UDP)", \
"connections/79.24.102.174.51097-10.11.3.3.6881_UDP" using 1:($2/1e6) with lines title "299(UDP)", \
"connections/79.242.94.56.22120-10.11.3.3.37212" using 1:($2/1e6) with lines title "285", \
"connections/80.71.129.116.58303-10.11.3.3.43651" using 1:($2/1e6) with lines title "510", \
"connections/84.2.125.223.2200-10.11.3.3.45555" using 1:($2/1e6) with lines title "484", \
"connections/85.228.205.253.51994-10.11.3.3.6881_UDP" using 1:($2/1e6) with lines title "174(UDP)", \
"connections/87.153.205.25.5020-10.11.3.3.35331" using 1:($2/1e6) with lines title "556", \
"connections/91.121.199.227.55999-10.11.3.3.34658" using 1:($2/1e6) with lines title "555"
