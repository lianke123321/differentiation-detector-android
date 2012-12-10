import sys, os
    
iptonames = {}
indexnames = {}

def makeIPNameHash(names):
    for line in open(names, 'r').readlines():
        l = line.strip().split('\t')
        if len(l) == 0: 
            continue
        if len(l) == 1:
            iptonames[str(l[0])] = "Unknown"  
        else:     
            iptonames[ str(l[0] )] = l[1]
       
def indexNameHash(names):
    n = 1
    indexnames["Unknown"] = 0
    for line in open(names, 'r').readlines():
       l = line.strip().split('\t')
       if len(l) == 0 or len(l) == 1:
           continue
       if str(l[1]) not in indexnames:
           indexnames[ str(l[1]) ] = n
           n = n+1


def IPToName(timestamps):
    outfile = open('namestotimestamps.txt', 'w')
    for line in open(timestamps, 'r').readlines():
        l = line.strip().split("\t")
        if len(l) == 0: 
            continue
        l[0] = iptonames[l[0]]
        num = indexnames[l[0]]
        outfile.write( str(num)+"\t\""+l[0] + "\"\t" + l[1]+"\n")
           
            
def run():
    IPTimestamps = sys.argv[1]
    IPNames = sys.argv[2]
    #splitFile(filename)
    makeIPNameHash(IPNames)
    indexNameHash(IPNames)
    IPToName(IPTimestamps)


if __name__ == '__main__':
    run()
