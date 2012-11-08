#!/usr/bin/env python


import sys
import string
import os
import glob
#import logging
import socket
import time
import collections
import parseMeddleData


# tcpdump-${clientID}-${timeStamp}-${PLUTO_ME}-${clientIP}-${PLUTO_PEER}.pcap.enc
# clientID = it is the name of the client in the certificate used by the client
# timeStamp = Month-Day-Year-Hour-Minute-TimeInSeconds(Epoch)
# PLUTO_ME = IP address of the VPN gateway
# clientIP = IP address used by the client (mobile device) in the tunnel (192.168.0.x) 
# PLUTO_PEER = The IP address of the mobile device

#source: private IP address

#logging.basicConfig(filename='example.log',level=logging.DEBUG)
#logging.basicConfig(level=logging.DEBUG)


hostName = socket.gethostname()
if hostName == 'placal' or hostName == 'nascal':
    rootResultDir = '/home/alegout/Meddle/Results'
    rootTraceDir = '/home/alegout/Meddle/pcap-data'
elif hostName == 'snowmane':
    rootResultDir = '/home/arnaud/Results'
    rootTraceDir = '/home/arnaud/meddle-data/pcap-data'


#I assume that each user has all its logs in the different directory in the 
#same root directory that is rootTraceDir
listUsersDir = [name for name in os.listdir(rootTraceDir)
                if os.path.isdir(os.path.join(rootTraceDir, name))]

############## BEGIN EXPERIMENTS CONFIGURATION #######################
print listUsersDir
#listUsersDir = listUsersDir[0:1]
listUsersDir = listUsersDir[:]

listUsersDir = listUsersDir[0:2]

#set to 1 to get the corresponding packets. Always get IP packets.
getTCP = 1  #for TCP and HTTP
getUDP = 0
getICMP = 0
getDNS = 0

dumpOptions = [getTCP, getUDP, getICMP, getDNS]

#0: dump each 'srcIP', 'dstIP', 'lenIP', 'ttlIP', 'proIP' in a different file
#   for scrIP and dstIP make a reverse DNS lookup.
#1: compute the frequency of IP packets emission with time
process = [1, 1]
 
print 'process', process
############## END    EXPERIMENTS CONFIGURATION ######################

step = 10

#return the DNS name for a given IP address and return the empty string 
#if the resolution cannot be performed
def getDNSName(s):
    try:
        DNSName = socket.gethostbyaddr(s)
    except socket.herror:
        DNSName = ''
    return DNSName

#write a line of 80 * with the string s centered 
def separator(s):
    lineWidth = 80
    leftStarNb = lineWidth / 2 - len(s)/2 - 1
    rightStarNb = lineWidth / 2 - len(s)/2 - len(s)%2 - 1
    sys.stdout.write('*'*leftStarNb + ' ' + s.upper() + ' ' + '*'*rightStarNb + '\n')


#used to list all user-agent entry in the HTTP headers
allUserAgent = dict()

#used to list all HTTP header fields
allHeadersKeys = dict()

#used to list all HTTP request methods
allRequestMethods = dict()

#used to list all HTTP URI
allUri = dict()


for user in listUsersDir:
    allFiles = glob.glob(os.path.join(rootTraceDir,user,'*pcap.enc.dec'))
    sys.stdout.write('\nProcess user ' + user + ' [' + str(len(allFiles)) + 
                     ' files, step=' + str(step)+ ']' + ' ')

 

    L = parseMeddleData.parse(user, allFiles, step, dumpOptions)
    ipList = L[0][0]
    srcIP, dstIP, lenIP, ttlIP, proIP = L[1][0], L[1][1], L[1][2], L[1][3], L[1][4]
    userAgent, userHeadersKeys, userRequestMethod, userUri = L[2][0], L[2][1], L[2][2], L[2][3]

    for k in userHeadersKeys:
        allHeadersKeys[k] = allHeadersKeys.get(k,0) + userHeadersKeys[k]

    for k in userRequestMethod:
        allRequestMethods[k] = allRequestMethods.get(k, 0) + userRequestMethod[k]

    for k in userAgent:
        allUserAgent[k] = allUserAgent.get(k, 0) + userAgent[k]

    for k in userUri:
        allUri[k] = allUri.get(k,0) + userUri[k]


    separator('Header Keys (Begin)')
    dumpFile = open(os.path.join(rootResultDir, user + '_allHeaderKeys.txt'), 'w')
    tmpList = [[v, k] for k, v in userHeadersKeys.iteritems()]
    tmpList.sort(reverse = True)
    for i in tmpList:
        dumpFile.write(str(i) + '\n')
        print i
    dumpFile.close()
    separator('Header Keys (End)')

    separator('Request Methods (Begin)')
    tmpList = [[v, k] for k, v in userRequestMethod.iteritems()]
    tmpList.sort(reverse = True)
    for i in tmpList:
        print i
    separator('Request Methods (End)')

    separator('user agent list (Begin)')
    dumpFile = open(os.path.join(rootResultDir, user + '_allUserAgent.txt'), 'w')
    tmpList = [[v, k] for k, v in userAgent.iteritems()]
    tmpList.sort(reverse = True)
    for i in tmpList:
        dumpFile.write(str(i) + '\n')
        print i
    dumpFile.close()
    separator('user agent list (End)')

    #separator('user URI (Begin)')
    dumpFile = open(os.path.join(rootResultDir, user + '_allUri.txt'), 'w')
    tmpList = [[v, k] for k, v in userUri.iteritems()]
    tmpList.sort(reverse = True)
    for i in tmpList:
        dumpFile.write(str(i) + '\n')
        #print i
    dumpFile.close()
    #separator('user URI (End)')

    if process[0] == 1:
        startTime = time.time()
        sys.stdout.write("Write files ... ")
        sys.stdout.flush()
        for dataStruct in ['srcIP', 'dstIP', 'lenIP', 'ttlIP', 'proIP']:
            dataStructList = eval(dataStruct)
            #count the number of each element in the list and return and dict
            countedElements = collections.Counter(dataStructList[0])

            if dataStruct in ['srcIP', 'dstIP']:
                tempStruct = [[countedElements[i], i, getDNSName(i)] for i in countedElements]
                #tempStruct = [[countedElements[i], i] for i in countedElements]
            else:
                tempStruct = [[countedElements[i], i] for i in countedElements]
            tempStruct.sort(reverse = True)
            dumpFile = open(os.path.join(rootResultDir, user + '_' + dataStruct + '.txt'), 'w')
            for i in tempStruct:
                dumpFile.write(str(i) + '\n')
            dumpFile.close()
        sys.stdout.write("done (" + str(time.time() - startTime) + ")\n")     
   
    if process[1] == 1:
        startTime = time.time()
        sys.stdout.write("Compute sending frequency ... ")
        sys.stdout.flush()
        timestamps = [int(i[0]) for i in ipList]
        sampleRange = (max(timestamps) - min(timestamps))
        minSample = min(timestamps)
        granularity = 60 #in seconds
        if sampleRange % granularity == 0:
            nbBins = sampleRange / granularity
        else:
            nbBins = (sampleRange / granularity) + 1

        #sampleList[i][0] contains the number of IP packets in the bin i
        #sampleList[i][1] contains the sum of the length of the IP packets in the bin i
        sampleList = [['NaN','NaN'] for i in range(nbBins)]

        for i in ipList:
            sampleRank = (int(i[0]) - minSample)/granularity
            if i[1][0] == 'B':
                sampleRankMin = (int(i[1][1]) - minSample)/granularity
                sampleRankMax = (int(i[1][2]) - minSample)/granularity
                for j in xrange(sampleRankMin,sampleRankMax + 1):
                    sampleList[j] = [0,0]
            else:
                sampleList[sampleRank][0] += 1
                sampleList[sampleRank][1] += int(i[1][2])      

        dumpFileCount = open(os.path.join(rootResultDir, user + '_frequency.txt'), 'w')
        for cpt2, i in enumerate(sampleList):
            dumpFileCount.write(str(cpt2*granularity) + ' ' + str(i[0]) + ' ' + str(i[1]) + '\n')
        dumpFileCount.close()

        sys.stdout.write("done (" + str(time.time() - startTime) + ")\n")        

#        ipdata.append(pkt)
#        tmp = ''.join([i for i in pkt.data.data if i in string.printable])
#        ipdataStr.append(tmp)

dumpFile = open(os.path.join(rootResultDir, 'allUserAgent.txt'), 'w')
tmpList = [[v, k] for k, v in allUserAgent.iteritems()]
tmpList.sort(reverse = True)
for i in tmpList:
    dumpFile.write(str(i) + '\n')
dumpFile.close()

dumpFile = open(os.path.join(rootResultDir, 'allHeaderKeys.txt'), 'w')
tmpList = [[v, k] for k, v in allHeadersKeys.iteritems()]
tmpList.sort(reverse = True)
for i in tmpList:
    dumpFile.write(str(i) + '\n')
dumpFile.close()

dumpFile = open(os.path.join(rootResultDir, 'allRequestMethods.txt'), 'w')
tmpList = [[v, k] for k, v in allRequestMethods.iteritems()]
tmpList.sort(reverse = True)
for i in tmpList:
    dumpFile.write(str(i) + '\n')
dumpFile.close()

dumpFile = open(os.path.join(rootResultDir, 'allUri.txt'), 'w')
tmpList = [[v, k] for k, v in allUri.iteritems()]
tmpList.sort(reverse = True)
for i in tmpList:
    dumpFile.write(str(i) + '\n')
dumpFile.close()
