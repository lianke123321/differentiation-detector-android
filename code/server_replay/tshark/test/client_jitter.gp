set title "UDP Jitter"
set style data lines
set key bottom right
set ylabel "CDF"
set xlabel "Jitter"
set yrange [0:1]
set term postscript color eps enhanced "Helvetica" 16
set style line 80 lt 0
set grid back linestyle 81
set border 3 back linestyle 80
set xtics nomirror
set ytics nomirror
set out "./test/cdf_udpjitter_client.ps"
a=0
cumulative_sum(x)=(a=a+x,a)
countpoints(file) = system( sprintf("grep -v ^# %s| wc -l", file) )
pointcount = countpoints("./test/client_delay_sorted.txt")
plot "./test/client_delay_sorted.txt" using 1:(1.0/pointcount) smooth cumulative with lines lw 3 linecolor rgb "green"
