set style data lines
set key off
set xlabel "Time (seconds)"
set ylabel "Cumulative Transfer (MB)"
set term postscript color eps enhanced "Helvetica" 24
set size ratio 0.5
# Line style for axes
set style line 80 lt 0
set grid back linestyle 81
set border 3 back linestyle 80
set xtics nomirror
set ytics nomirror
set out 'doublep.ps'
plot "../tmobile_hsdpa+_nfx/connections/108.175.35.155.80-10.11.3.3.50183" using 1:($2/1e6) with lines lw 7 lt 1 linecolor 2 title "tmobile_hsdpa+_nfx (A)", \
"../tmobile_hsdpa+_nfx/connections/108.175.35.155.80-10.11.3.3.50187" using 1:($2/1e6) with lines lw 7 lt 1 linecolor 3 title "tmobile_hsdpa+_nfx (B)", \
"../tmobile_hsdpa+_nfx/connections/108.175.35.155.80-10.11.3.3.50188" using 1:($2/1e6) with lines lw 7 lt 1 linecolor 4 title "tmobile_hsdpa+_nfx (C)", \
"../tmobile_hsdpa+_nfx/connections/108.175.35.155.80-10.11.3.3.50192" using 1:($2/1e6) with lines lw 7 lt 1 linecolor rgb '#006400' title "tmobile_hsdpa+_nfx (D)", \
"../tmobile_hsdpa+_nfx/connections/23.0.160.43.80-10.11.3.3.57123" using 1:($2/1e6) with lines lw 7 lt 1 linecolor 6 title "tmobile_hsdpa+_nfx (E)", \
"../university_nfx/connections/108.175.35.155.80-10.11.3.3.48967" using 1:($2/1e6) with lines lw 7 lt 3 linecolor 2 title "university_nfx (A)", \
"../university_nfx/connections/108.175.35.155.80-10.11.3.3.48969" using 1:($2/1e6) with lines lw 7 lt 3 linecolor 3 title "university_nfx (B)", \
"../university_nfx/connections/108.175.35.155.80-10.11.3.3.48970" using 1:($2/1e6) with lines lw 7 lt 3 linecolor 4 title "university_nfx (C)", \
"../university_nfx/connections/108.175.35.155.80-10.11.3.3.48975" using 1:($2/1e6) with lines lw 7 lt 3 linecolor 5 title "university_nfx (D)", \
"../university_nfx/connections/108.175.35.155.80-10.11.3.3.48976" using 1:($2/1e6) with lines lw 7 lt 3 linecolor 6 title "university_nfx (E)", \
"../university_nfx/connections/108.175.35.155.80-10.11.3.3.48978" using 1:($2/1e6) with lines lw 7 lt 3 linecolor rgb '#006400' title "university_nfx (F)", \
"../university_nfx/connections/184.51.126.58.80-10.11.3.3.35946" using 1:($2/1e6) with lines lw 7 lt 3 linecolor 8 title "university_nfx (G)"