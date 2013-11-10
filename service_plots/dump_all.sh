#! /bin/sh

rm -rf plots/*
rm -rf text_pcaps/*

for f in `cd pcaps;ls *.pcap;cd ..`
do
    name=`echo "$f" | cut -d'.' -f1`
    tcpdump -nr pcaps/$f >text_pcaps/$name.txt
    mkdir plots/$name
    cd plots/$name
    echo ../../filterer/filter ../../text_pcaps/$name.txt `cat ../../confs/"$name"` >filterit.sh
    chmod +x filterit.sh
    ./filterit.sh
    cd ../..
done
