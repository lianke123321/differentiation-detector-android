import sys

notFound="NOTFOUND"
serverIPs = ["138.96.16.49", "128.208.4.186", "128.208.4.189", notFound];
if len(sys.argv) != 3:
    print " "+str(sys.argv[0]) + " <fName> <type>"
    sys.exit(-1)
fName=sys.argv[1]
ipType=sys.argv[2]
for servP in serverIPs:
   if fName.find(servP) != -1:
      break
if servP == notFound:
   print notFound
   sys.exit(-1)
if ipType == "1":
    print fName.split("-")[-1].split(".pcap")[0]
else:
    print fName.split(servP)[1].split("-")[1]
