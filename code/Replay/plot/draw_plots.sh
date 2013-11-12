#! /bin/sh

# Just clean the results.
if [ $# -eq 1 ]; then
    if [ $1 = "clean" ]; then
	rm -rf ../data/generated_plots
	rm -rf ../data/text_pcaps
	exit
    fi
fi


# Clean the results.
rm -rf ../data/generated_plots
rm -rf ../data/text_pcaps

mkdir ../data/generated_plots
mkdir ../data/text_pcaps

cd filterer
make
cd ..

# For every pcap you find in data/pcaps
for f in `cd ../data/pcaps;ls *.pcap;cd ../../plot`
do
    # Filter out the name (strip the extention).
    name=`echo "$f" | cut -d'.' -f1`
    # Dump the pcap to plain text using tcpdump.
    tcpdump -nr ../data/pcaps/$f >../data/text_pcaps/$name.txt
    # Make the directory for the plot.
    mkdir ../data/generated_plots/$name
    cd ../data/generated_plots/$name
    # Generate the script to draw the plot.
    echo ../../../plot/filterer/filter ../../text_pcaps/$name.txt `cat ../../confs/"$name"` >filterit.sh
    chmod +x filterit.sh
    # Run the script.
    ./filterit.sh
    # Go back.
    cd ../../../plot
done
