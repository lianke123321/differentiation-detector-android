set style data lines
set title "YouTube (watch) (cutoff threshold = 100000)"
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
plot "connections/10.11.3.3.33580-23.0.160.72.80" using 1:($2/1e6) with lines title "68", \
"connections/10.11.3.3.36819-74.125.226.228.443" using 1:($2/1e6) with lines title "64", \
"connections/10.11.3.3.37119-74.125.226.229.443" using 1:($2/1e6) with lines title "4", \
"connections/10.11.3.3.37757-74.125.29.95.443" using 1:($2/1e6) with lines title "8", \
"connections/10.11.3.3.39304-74.125.228.65.443" using 1:($2/1e6) with lines title "19", \
"connections/10.11.3.3.40585-74.125.228.107.443" using 1:($2/1e6) with lines title "14", \
"connections/10.11.3.3.41085-173.252.100.27.443" using 1:($2/1e6) with lines title "79", \
"connections/10.11.3.3.41221-74.125.226.228.443" using 1:($2/1e6) with lines title "75", \
"connections/10.11.3.3.41496-208.91.159.108.80" using 1:($2/1e6) with lines title "24", \
"connections/10.11.3.3.41560-74.125.228.64.443" using 1:($2/1e6) with lines title "27", \
"connections/10.11.3.3.42174-74.125.228.70.443" using 1:($2/1e6) with lines title "45", \
"connections/10.11.3.3.42500-74.125.29.95.443" using 1:($2/1e6) with lines title "16", \
"connections/10.11.3.3.43241-74.125.226.229.443" using 1:($2/1e6) with lines title "49", \
"connections/10.11.3.3.43900-74.125.228.64.443" using 1:($2/1e6) with lines title "35", \
"connections/10.11.3.3.43914-74.125.228.107.443" using 1:($2/1e6) with lines title "12", \
"connections/10.11.3.3.44139-74.125.29.95.443" using 1:($2/1e6) with lines title "41", \
"connections/10.11.3.3.44364-74.125.228.67.443" using 1:($2/1e6) with lines title "2", \
"connections/10.11.3.3.45055-74.125.226.229.443" using 1:($2/1e6) with lines title "48", \
"connections/10.11.3.3.47273-208.91.159.108.80" using 1:($2/1e6) with lines title "39", \
"connections/10.11.3.3.47762-74.125.228.65.443" using 1:($2/1e6) with lines title "18", \
"connections/10.11.3.3.48562-173.252.112.23.443" using 1:($2/1e6) with lines title "77", \
"connections/10.11.3.3.49298-74.125.228.64.443" using 1:($2/1e6) with lines title "37", \
"connections/10.11.3.3.49750-74.125.228.72.80" using 1:($2/1e6) with lines title "22", \
"connections/10.11.3.3.50084-74.125.228.64.443" using 1:($2/1e6) with lines title "28", \
"connections/10.11.3.3.50339-74.125.226.229.443" using 1:($2/1e6) with lines title "25", \
"connections/10.11.3.3.51917-69.171.245.49.443" using 1:($2/1e6) with lines title "73", \
"connections/10.11.3.3.52018-208.91.159.108.80" using 1:($2/1e6) with lines title "40", \
"connections/10.11.3.3.53014-74.125.226.229.443" using 1:($2/1e6) with lines title "6", \
"connections/10.11.3.3.54456-74.125.226.229.443" using 1:($2/1e6) with lines title "47", \
"connections/10.11.3.3.59535-74.125.228.124.80" using 1:($2/1e6) with lines title "55", \
"connections/173.194.7.201.80-10.11.3.3.35859" using 1:($2/1e6) with lines title "60", \
"connections/173.252.100.27.443-10.11.3.3.41085" using 1:($2/1e6) with lines title "80", \
"connections/173.252.112.23.443-10.11.3.3.48562" using 1:($2/1e6) with lines title "78", \
"connections/74.125.226.228.443-10.11.3.3.36819" using 1:($2/1e6) with lines title "65", \
"connections/74.125.226.228.443-10.11.3.3.41221" using 1:($2/1e6) with lines title "76", \
"connections/74.125.226.229.443-10.11.3.3.37119" using 1:($2/1e6) with lines title "5", \
"connections/74.125.226.229.443-10.11.3.3.43241" using 1:($2/1e6) with lines title "51", \
"connections/74.125.226.229.443-10.11.3.3.45055" using 1:($2/1e6) with lines title "52", \
"connections/74.125.226.229.443-10.11.3.3.50339" using 1:($2/1e6) with lines title "26", \
"connections/74.125.226.229.443-10.11.3.3.53014" using 1:($2/1e6) with lines title "7", \
"connections/74.125.226.229.443-10.11.3.3.54456" using 1:($2/1e6) with lines title "50", \
"connections/74.125.228.107.443-10.11.3.3.40585" using 1:($2/1e6) with lines title "15", \
"connections/74.125.228.107.443-10.11.3.3.43914" using 1:($2/1e6) with lines title "13", \
"connections/74.125.228.107.80-10.11.3.3.54736" using 1:($2/1e6) with lines title "54", \
"connections/74.125.228.124.80-10.11.3.3.59535" using 1:($2/1e6) with lines title "56", \
"connections/74.125.228.64.443-10.11.3.3.41560" using 1:($2/1e6) with lines title "29", \
"connections/74.125.228.64.443-10.11.3.3.43900" using 1:($2/1e6) with lines title "36", \
"connections/74.125.228.64.443-10.11.3.3.49298" using 1:($2/1e6) with lines title "38", \
"connections/74.125.228.64.443-10.11.3.3.50084" using 1:($2/1e6) with lines title "31", \
"connections/74.125.228.64.443-10.11.3.3.52539" using 1:($2/1e6) with lines title "33", \
"connections/74.125.228.64.443-10.11.3.3.60093" using 1:($2/1e6) with lines title "34", \
"connections/74.125.228.65.443-10.11.3.3.39304" using 1:($2/1e6) with lines title "21", \
"connections/74.125.228.65.443-10.11.3.3.47762" using 1:($2/1e6) with lines title "20", \
"connections/74.125.228.65.80-10.11.3.3.41164" using 1:($2/1e6) with lines title "44", \
"connections/74.125.228.67.443-10.11.3.3.44364" using 1:($2/1e6) with lines title "3", \
"connections/74.125.228.70.443-10.11.3.3.42174" using 1:($2/1e6) with lines title "46", \
"connections/74.125.228.70.80-10.11.3.3.39401" using 1:($2/1e6) with lines title "1", \
"connections/74.125.228.72.80-10.11.3.3.49750" using 1:($2/1e6) with lines title "23", \
"connections/74.125.29.95.443-10.11.3.3.37757" using 1:($2/1e6) with lines title "9", \
"connections/74.125.29.95.443-10.11.3.3.42500" using 1:($2/1e6) with lines title "17", \
"connections/74.125.29.95.443-10.11.3.3.44139" using 1:($2/1e6) with lines title "42"
