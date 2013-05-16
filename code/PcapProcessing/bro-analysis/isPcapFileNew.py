import sys

notFound="NOTFOUND"
serverIPs = ["138.96.16.49", "128.208.4.186", "128.208.4.189", notFound];
if len(sys.argv) != 3:
    print " "+str(sys.argv[0]) + " <fName> <ts>"
    sys.exit(-1)
fName=sys.argv[1]
ts=int(sys.argv[2])
for servP in serverIPs:
   if fName.find(servP) != -1:
      break
if servP == notFound:
   print notFound
   sys.exit(-1)
tsVal=int(fName.split(servP)[0].split('-')[-2])
if tsVal > ts: 
   print 1
   exit(0)
print 0
