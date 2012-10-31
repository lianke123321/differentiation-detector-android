for dirname in arao-droid arao-ipod dave-droid dave-ipad dave-iphone; 
do  
    cd ${dirname}
    for d in tcpdump-*; 
    do 
        gpg --homedir=/data/.gpg --no-default-keyring --secret-keyring /data/.gpg/Meddle.secret --keyring /data/.gpg/Meddle.key -o ${d}.dec --passphrase S@#dvnjkurEqr6uhdfSxVh12d --decrypt ${d}; 
    done; 
    rm -f *.enc; 
    rename .pcap.enc.dec .pcap *
    cd -
    fName="file-list-${dirname}"
    ls -l ${dirname} > ${fName}
    echo ${fName}
    awk '{print $5 " " $9}' ${fName} | cut -d '-' -f 1,12 | sed 's/tcpdump-//g' - | sed 's/\.pcap//g' | awk '{print $2 " " $1}'  | sort -n  > meta-${dirname}
done
