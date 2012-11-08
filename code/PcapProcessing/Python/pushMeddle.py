#!/usr/bin/env python

import sys
import os
import socket
import time

out=sys.stderr
snowmane='snowmane.cs.washington.edu'

parameters =  ['pcap', 'res']
workingMachine = ['placal', 'nascal']

if len(sys.argv) != 3 or (len(sys.argv) == 3 and 
                          ((sys.argv[1] not in workingMachine) or (sys.argv[2] not in parameters))):
    print """USAGE: push.py <machine> <parameter>
               <machine> in """ + str(workingMachine) + """

               <parameter> = pcap : push all pcap files from snowmane to <machine>
               <parameter> = res : push all result files from <machine> to my local machine and to snowmane"""
    sys.exit('')


rsyncCommands = []
if sys.argv[2] == parameters[0]:
    rsyncCommands.append('ssh ' + sys.argv[1] + '.inria.fr rsync -avz --chmod=Du+rwx,Fu+rw --delete --exclude=*.pcap.enc.dec --exclude=.svn --exclude=*~  arnaud@' + snowmane + ':/home/arnaud/meddle-data/pcap-data /home/alegout/Meddle')
    rsyncCommands.append('ssh ' + sys.argv[1] + '.inria.fr python /home/alegout/Meddle/Python/decrypt.py')


if sys.argv[2] == parameters[1]:
    rsyncCommands.append('rsync -avz --chmod=Du+rwx,Fu+rw --delete --exclude=.svn --exclude=*~  ' + sys.argv[1] + '.inria.fr:/home/alegout/Meddle/Results/* /cygdrive/c/Backup/INRIA/Research/Meddle/localSVN/Results/.')
    rsyncCommands.append('rsync -avz --chmod=Du+rwx,Fu+rw --delete --exclude=.svn --exclude=*~  /cygdrive/c/Backup/INRIA/Research/Meddle/localSVN/Results/* arnaud@' + snowmane + ':/home/arnaud/Results/.')

for com in rsyncCommands:
    print("********** RUNNING: " + com)
    os.system(com)


#RSYNC_RSH="ssh acces.sophia.grid5000.fr ssh" rsync -avz . --exclude=.svn --exclude=*~ --exclude=Logs frontend.rennes.grid5000.fr:Python/.
#RSYNC_RSH="ssh acces.sophia.grid5000.fr ssh" rsync -avz ../NOSAVE/Content --exclude=.svn --exclude=*~ --exclude=Logs frontend.rennes.grid5000.fr:

#rsync -avz . --exclude=.svn --exclude=*~ --exclude=Logs acces.sophia.grid5000.fr:Python/.
#rsync -avz ../NOSAVE/Content --exclude=.svn --exclude=*~ --exclude=Logs acces.sophia.grid5000.fr:
