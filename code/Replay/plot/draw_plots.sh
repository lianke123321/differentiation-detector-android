#! /bin/sh

if [ $1 = "clean" ]; then
    rm -rf ../data/generated_plots/*
    rm -rf ../data/text_pcaps/*
    exit
fi


rm -rf ../data/generated_plots/*
rm -rf ../data/text_pcaps/*

for f in `cd ../data/pcaps;ls *.pcap;cd ../../plot`
do
    name=`echo "$f" | cut -d'.' -f1`
    tcpdump -nr ../data/pcaps/$f >../data/text_pcaps/$name.txt
    mkdir ../data/generated_plots/$name
    cd ../data/generated_plots/$name
    echo ../../../plot/filterer/filter ../../text_pcaps/$name.txt `cat ../../confs/"$name"` >filterit.sh
    chmod +x filterit.sh
    ./filterit.sh
    cd ../../../plot
done
