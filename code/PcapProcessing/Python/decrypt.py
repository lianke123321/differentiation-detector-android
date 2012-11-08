#!/usr/bin/env python

import sys
import string
import os
import glob
import time
import socket

# tcpdump-${clientID}-${timeStamp}-${PLUTO_ME}-${clientIP}-${PLUTO_PEER}.pcap.enc
# clientID = it is the name of the client in the certificate used by the client
# timeStamp = Month-Day-Year-Hour-Minute-TimeInSeconds(Epoch)
# PLUTO_ME = IP address of the VPN gateway
# clientIP = IP address used by the client (mobile device) in the tunnel (192.168.0.x) 
# PLUTO_PEER = The IP address of the mobile device

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

############## END    EXPERIMENTS CONFIGURATION ######################

step = 10

for user in listUsersDir:
    allFiles = glob.glob(os.path.join(rootTraceDir,user,'*pcap.enc'))
    sys.stdout.write('\nProcess user ' + user + ' [' + str(len(allFiles)) + 
                     ' files, step=' + str(step)+ ']' + ' ')

    startTime = time.time()
    
    for cpt, myFile in enumerate(allFiles):

        if cpt%step == 0:
            sys.stdout.write('.')
            sys.stdout.flush()
        if os.path.getsize(myFile) == 0:
            continue
        
        cmd = 'gpg --homedir=~/Meddle/.gpg --batch --no-tty --quiet --no-default-keyring  --passphrase S@#dvnjkurEqr6uhdfSxVh12d --secret-keyring ~/Meddle/.gpg/Meddle.secret --keyring ~/Meddle/.gpg/Meddle.key -o ' + myFile + '.dec' + ' --decrypt ' + myFile

        os.system(cmd)
