def parseRow(entry):
    entry=entry.strip('\n')
    entry=entry.split("\t")
    #print(entry)
    ts, srcIP, srcPort, dstIP, dstPort= entry[1], entry[2], entry[3], entry[4], entry[5]
    fqdn, resp, ttls = entry[8], entry[20], entry[21]
    operating_system, user_id= entry[22], entry[23]
    #print operating_system, user_id
    #sys.exit(-1)
    resp=resp.split(",")
    if len(resp)>0:
        # filter out any names for the time being
        resp = filter(lambda(x): x.replace(".","").isdigit(), resp)
    ttls=ttls.split(",")
    if len(ttls) > 0:
        ttls=[e.split(".")[0] for e in ttls]
        # Make sure we have the corresponding entries in ttls in resp 
        ttls = ttls[-len(resp):]     
    if (dstPort=="53"):
        clientIP = srcIP
    else:
        clientIP = dstIP
    return zip([ts]*len(resp), [fqdn]*len(resp), [clientIP]*len(resp), resp, ttls, [user_id]*len(resp), [operating_system]*len(resp), range(1,len(resp)+1))

def createTable(dstPath, inpPath):
    print("Opening the files\n")
    fw = open(dstPath,"w")
    fi = open(inpPath,"r")
    fw.write("ts\tfqdn\tclient_ip\tserver_ip\tttl\tpkg_id\tpkg_name\tresp_order\n")
    print("Now parsing the entries\n")
    cnt=0
    for line in fi:
        results = parseRow(line)
        for entry in results:
            fw.write('\t'.join(str(e) for e in entry))
            fw.write('\n')
        # end entry
        cnt = cnt + 1  
        if cnt % 100000 == 0:
           print cnt
    #end for
    fw.close()
    fi.close()
            

if __name__=="__main__":
    createTable("../bro-results/droid-10-min-amy/lookup.dns.log.pkg", "../bro-results/droid-10-min-amy/dns.log.pkg") 
