"""
This module provides a function parse() that parses a pcap file and
extract the data structures used for its processing 
"""

import dpkt
import sys
import os
import time


#check if an IP address octet in in the range [0,255]
def valid(i):
    if i>= '\x00' and i <='\xff':
        return True
    else:
        print('invalid IP address')
    
#convert an IP address represented as an hex string to a dotted decimal notation
def conv(s):
    return ".".join([str(ord(i)) for i in s if valid(i)])
 


def parse(user, allFiles, step, dumpOptions):
    """
    parse(user, allFiles): 
                    <allFiles> is a list of pcap files coming from a single user named <user>
                    
                    return a list L
                    L[0] is the list [ipList, tcpList, udpList, dnsList, icmpList]
                         ipList is computed on all files for a single user, thus it contains
                                a complete view of the user
                                ipList = [timestamp in seconds, [IPsrc, IPdst, IPtotalLen, 
                                                                 IPttl, IPidentification, 
                                                                 IPfragOff, IPprotocol]]
                          tcpList, udpList, dnsList, icmpList are not yet fully implemented

                    L[1] is the list [srcIP, dstIP, lenIP, ttlIP, proIP]
                         srcIP = [srcIPList, srcIPSet]
                               srcIPList is the list of all source IP adresses found in ipList
                               srcIPSet is a python set computed on srcIPList
                         dstIP, lenIP, ttlIP, proIP are computed similarly for destination IP
                         addresses, TTLs, and IP protocols respectively

                    L[2] is the list [userAgent, userHeadersKeys, userRequestMethod, userUri]
                         userAgent is a dictionnary that contains as keys the HTTP user-agents
                                   and as values the number of occurence of this user-agent
                                   in all HTTP headers for a single user
                          userHeadersKeys, userRequestMethod, userUri are computed similarly for
                          the header keys, the request methods, and the URI respectively. 
    """

    startTime = time.time()
    userName, userDevice = tuple(user.split('-'))
    
    ipAllFiles, ipList, tcpList, udpList, dnsList, icmpList =[], [], [], [], [], []

    #HTTP dict used to keep count of some specific values (user-agent,
    #headers keys, request method, URI)  
    userAgent = dict()
    userHeadersKeys = dict()
    userRequestMethod = dict()
    userUri = dict()

    getTCP, getUDP, getICMP, getDNS = dumpOptions[0], dumpOptions[1], dumpOptions[2], dumpOptions[3]

    for cpt, myFile in enumerate(allFiles):
        try:
            #extract the IP addresses used by the VPN operation from the file name
            # knowIPs[0]: IP address of the VPN gateway
            # knownIPs[1]: IP address used by the client (mobile device) in the tunnel (192.168.0.x) 
            # knowIPs[2]: public IP address of the mobile device
            knownIPs = os.path.split(myFile)[1].split('-')[-3:]  #get the 3 IP addresses
            knownIPs[2] = knownIPs[2][:-13]  #from the last IP addresses remove .pcap.enc.dec at the end
        except IndexError:
            print 'WARNING: Error parsing file to extract knownIPs: ', myFile

        ipOneFile = [knownIPs, []]
        if cpt%step == 0:
            sys.stdout.write('.')
            sys.stdout.flush()
        if os.path.getsize(myFile) == 0:
            continue
        f = open(myFile)
        #test the case of a non empty file, but that is too short to contain a 
        #full valid packet.
        try:
            pcap = dpkt.pcap.Reader(f)
        except dpkt.pcap.EndOfFile:
            f.seek(0,2)
            print 'File ' + myFile + ' too short ' + str(f.tell()) + ' to contain a full packet'
        
        isEndOfFile = 0
        packetCount = 0
        noPayloadPackets = 0 
        attributeErrorPacket = 0
        needDataPackets = 0
        #ts is the timestamp of capture of the packet buf
        for ts, buf in pcap:
            packetCount = packetCount + 1
            #get IP packets
            #we test if NeedData is raised at the end of the file (which is fine 
            #and can be skipped because the EOF might be corrupted), or in the 
            #middle of the file, which is not normal and should raise an exception
            try:
                ip = dpkt.ip.IP(buf)
                ipHeader = (conv(ip.src), conv(ip.dst), ip.len, ip.ttl, ip.id, ip.off, ip.p)
                ipOneFile[1].append([ts,ipHeader])
                #print ts, time.ctime(ts)
                #if ipHeader[1] == '138.96.198.246':
                #     print file, ipHeader, ip.src, ip.dst, ip.len, ip.ttl
            except dpkt.NeedData:
                if isEndOfFile:
                    raise
                else:
                    isEndOfFile = 1

            #get TCP packets
            if getTCP and ip.p == dpkt.ip.IP_PROTO_TCP :
                tcp = ip.data
                tcpList.append(tcp)
                try:
                    if tcp.dport == 80:
                        payload = tcp.data
                        if payload:
                            try:
                                http = dpkt.http.Request(payload)
                            except (dpkt.NeedData, dpkt.UnpackError): #TODO cacth the correct exceptions
                                needDataPackets = needDataPackets + 1
                                http = None
                            if http:
                                tmp = http.headers.get('user-agent', '')
                                userAgent[tmp] = userAgent.get(tmp, 0) + 1
                                for k in http.headers.keys():
                                    userHeadersKeys[k] = userHeadersKeys.get(k, 0) + 1        
                                tmp = http.method
                                userRequestMethod[tmp] = userRequestMethod.get(tmp, 0) + 1
                                tmp = http.headers.get('host', '') + http.uri
                                userUri[tmp] = userUri.get(tmp, 0) + 1
                        else:
                            #no payload packets might be to due to keep alive messages 
                            #at the application layer.  
                            noPayloadPackets = noPayloadPackets + 1
                            
                except AttributeError: 
                    #attribute error packets might be due to corrupted packet at the 
                    #end of a file, or to fragmented packets at the IP layer
                    attributeErrorPacket = attributeErrorPacket + 1

            #get UDP packets
            elif getUDP and ip.p == dpkt.ip.IP_PROTO_UDP:
                udp = ip.data
                udpList.append(udp)
            #get DNS packets
                if getDNS and (udp.dport == 53 or udp.sport == 53):
                    dns = dpkt.dns.DNS(udp.data)
                    dnsList.append(dns)

            #get ICMP packets
            elif getICMP and ip.p == dpkt.ip.IP_PROTO_ICMP:
                icmp = ip.data
                icmpList.append(icmp)

        #here I check that ipOneFile is not empty
        if ipOneFile[1]:
            ipAllFiles.append(ipOneFile)
    else:
        sys.stdout.write("done (" + str(time.time() - startTime) + ")\n")




    #f_test = open(os.path.join(rootResultDir, 'test.txt'), 'w')
    for i in ipAllFiles:
        #B is to mark the beginning of the file, I add an offset of 0.0001 to be
        #sure that this entry is first after sorting. This entry gives the first and
        #last time stamp during which the VPN is up and running.
        #IMPORTANT NOTE: It is not possible to be sure that the VPN has been 
        #stopped or that no traffic has been sent. 
        tmpMin = min((j[0] for j in i[1]))
        tmpMax = max((j[0] for j in i[1]))
        ipList.append([tmpMin-0.0001, ('B', tmpMin, tmpMax, 'S', 'S', 'S', 'S')])
        ipList.extend(i[1])
       # timestamps = [int(j[0]) for j in i[1]]
       # f_test.write(str(min(timestamps)) + ' ' +str(max(timestamps)) + ' NaN ')
       # print min(timestamps), max(timestamps)

        #E is to mark the end of the file, I remove an offset of 0.0001 to be 
        #sure that this entry is last after sorting
        #ipList.append([tmp+0.0001, ('E', 'E', 'E', 'E', 'E', 'E', 'E')])
    #f_test.close()
    startTime = time.time()
    sys.stdout.write("Sorting list ... ")
    sys.stdout.flush()

    #only sort on the time stamps
    ipList.sort(cmp = lambda x, y: cmp(x[0], y[0]))
    sys.stdout.write("done (" + str(time.time() - startTime) + ")\n")


    startTime = time.time()
    #build the data structures for processing
    sys.stdout.write("Building data structures ... ")
    sys.stdout.flush()
    #remove knownIPs from the lists.
    #TODO: check that knowIPs effectively filters out known IPs
    srcIPList = [i[1][0] for i in ipList if i not in knownIPs]
    dstIPList = [i[1][1] for i in ipList if i not in knownIPs]
    lenIPList = [i[1][2] for i in ipList]
#    ttlIPList=[]
#    for i in ipList:
#        print i
#        ttlIPList.append(i[1][3])
    ttlIPList = [i[1][3] for i in ipList]
    proIPList = [i[1][6] for i in ipList]

    srcIPSet = set(srcIPList)
    dstIPSet = set(dstIPList)
    lenIPSet = set(lenIPList)
    ttlIPSet = set(ttlIPList)
    proIPSet = set(proIPList)

    srcIP = [srcIPList, srcIPSet]
    dstIP = [dstIPList, dstIPSet]
    lenIP = [lenIPList, lenIPSet]
    ttlIP = [ttlIPList, ttlIPSet]
    proIP = [proIPList, proIPSet]
    sys.stdout.write("done (" + str(time.time() - startTime) + ")\n")

    print("# IP src unique " + str(len(srcIPSet)) + ", # IP dst unique " + str(len(dstIPSet)) + 
          ", # len unique " + str(len(lenIPSet)) + ", # ttl unique " + str(len(ttlIPSet)) + 
          ", # pro unique " + str(len(proIPSet)))

    #build the data structure to return
    L = []
    L.append([ipList, tcpList, udpList, dnsList, icmpList])
    L.append([srcIP, dstIP, lenIP, ttlIP, proIP])
    L.append([userAgent, userHeadersKeys, userRequestMethod, userUri])
    return L
