import sys

if len(sys.argv) != 3:
    print " "+str(sys.argv[0]) + " <fName> <type>"
    sys.exit(-1)
fName=sys.argv[1]
ipType=sys.argv[2]
if ipType == "1":
    print fName.split("-")[-1].split(".pcap")[0]
else:
    print fName.split("128.")[1].split("-")[1]
