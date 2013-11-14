for i in `head -10000 top-1m.csv`; do echo  "$RANDOM $i"; done | sort | sed -E 's/^[0-9]+ //'  | cut -d ',' -f 2 > randorder-10k.csv;
