baseDir="/user/arao/home/meddle_data/"
decryptDir="${baseDir}/pcap-decrypted/"
for uName in 05c2c53df8 1bb03d7910 331767035e 38b8bc378a 4187a11259 516de0e1bd 56ac018d49 5a1cd42eff 9c8c7fd5cf a8d88b9b98 adrian amy-droid arao-droid arao-ipod arnaud-iphone arvind-iphone cf6ba20782 d2628b24f6 d4507b60cb dave-droid dave-ipad dave-iphone dave-iphone-3gs dcce6372e4 e007dba768 f67a6dc4b5 parikshan-droid sam shen-ios syhan-droid uw101-droid uw103-droid uw104-droid uw106-iphone will-droid will-ipad
do
    uDir=${decryptDir}/${uName}
    uName=`basename ${uDir}`
    echo ${uName}
    ./run-bro.sh ${uName} > ${baseDir}/Routs/bro-${uName}.log 2>&1
done
