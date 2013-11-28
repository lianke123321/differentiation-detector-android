def parseRow(entry):
    entry=entry.strip('\n')
    entry=entry.split("\t")
    #print(entry)
    ts, srcIP, srcPort, dstIP, dstPort= entry[1], entry[2], entry[3], entry[4], entry[5]
    fqdn, resp, ttls = entry[8], entry[20], entry[21]
    operating_system, user_id = entry[35], entry[37]
    resp=resp.split(",")
    if len(resp)>0:
        # filter out any names for the time being
        resp = filter(lambda(x): x.replace(".","").isdigit(), resp)
    ttls=ttls.split(",")
    if len(ttls) > 0:
        ttls=[e.split(".")[0] for e in ttls]
        # Make sure we have the corresponding entries in ttls in resp 
        ttls = ttls[-len(resp):]     
    if (dstPort==53):
        clientIP = srcIP
    else:
        clientIP = dstIP
    return zip([ts]*len(resp), [fqdn]*len(resp), [clientIP]*len(resp), resp, ttls, [operating_system]*len(resp), [user_id]*len(resp), range(1,len(resp)+1))

def createTable(dstPath, inpPath):
    fw = open(dstPath,"w")
    fi = open(inpPath,"r")
    fw.write("ts\tfqdn\tclient_ip\tserver_ip\tttl\toperating_system\tuser_id\tresp_order\n")
    for line in fi:
        results = parseRow(line)
        for entry in results:
            fw.write('\t'.join(e for e in entry))
            fw.write('\n')
        # end entry
    #end for
    fw.close()
    fi.close()
            

if __name__=="__main__":
    createTable("./results.log", "./test-dns.log.info")
                     
            





               
    


  
