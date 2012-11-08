#!/usr/bin/env python

import sys
import os
import socket
import time

out=sys.stderr
shortMachineName =  ['all', 'snow', 'placal', 'nascal']
localFolder = '/cygdrive/c/Backup/INRIA/Research/Meddle/localSVN/'

if len(sys.argv) != 2 or (len(sys.argv) == 2 and not (sys.argv[1] in shortMachineName)):
    print """USAGE: sync.py <shortMachineName>
               shortMachineName in """ + str(shortMachineName)
    sys.exit('')


rsyncCommands=[]
if sys.argv[1] == shortMachineName[0] or sys.argv[1] == shortMachineName[1]:
    rsyncCommands.append('rsync -avz --chmod=Du+rwx,Fu+rw --delete --exclude=.svn --exclude=*~ --exclude=*.enc ' + os.path.join(localFolder, 'Python') + ' arnaud@snowmane.cs.washington.edu:/home/arnaud')
    rsyncCommands.append('rsync -avz --chmod=Du+rwx,Fu+rw --delete --exclude=.svn --exclude=*~ --exclude=*.enc ' + os.path.join(localFolder, 'Matlab') + ' arnaud@snowmane.cs.washington.edu:/home/arnaud')

if sys.argv[1] == shortMachineName[0] or sys.argv[1] == shortMachineName[2]:
    rsyncCommands.append('rsync -avz --chmod=Du+rwx,Fu+rw --delete --exclude=.svn --exclude=*~ --exclude=*.enc ' + os.path.join(localFolder, 'Python') + ' alegout@placal.inria.fr:/home/alegout/Meddle')
    rsyncCommands.append('rsync -avz --chmod=Du+rwx,Fu+rw --delete --exclude=.svn --exclude=*~ --exclude=*.enc ' + os.path.join(localFolder, 'Matlab') + ' alegout@placal.inria.fr:/home/alegout/Meddle')

if sys.argv[1] == shortMachineName[0] or sys.argv[1] == shortMachineName[3]:
    rsyncCommands.append('rsync -avz --chmod=Du+rwx,Fu+rw --delete --exclude=.svn --exclude=*~ --exclude=*.enc ' + os.path.join(localFolder, 'Python') + ' alegout@nascal.inria.fr:/home/alegout/Meddle')
    rsyncCommands.append('rsync -avz --chmod=Du+rwx,Fu+rw --delete --exclude=.svn --exclude=*~ --exclude=*.enc ' + os.path.join(localFolder, 'Matlab') + ' alegout@nascal.inria.fr:/home/alegout/Meddle')


for com in rsyncCommands:
    print("********** RUNNING: " + com)
    os.system(com)


#RSYNC_RSH="ssh acces.sophia.grid5000.fr ssh" rsync -avz . --exclude=.svn --exclude=*~ --exclude=Logs frontend.rennes.grid5000.fr:Python/.
#RSYNC_RSH="ssh acces.sophia.grid5000.fr ssh" rsync -avz ../NOSAVE/Content --exclude=.svn --exclude=*~ --exclude=Logs frontend.rennes.grid5000.fr:

#rsync -avz . --exclude=.svn --exclude=*~ --exclude=Logs acces.sophia.grid5000.fr:Python/.
#rsync -avz ../NOSAVE/Content --exclude=.svn --exclude=*~ --exclude=Logs acces.sophia.grid5000.fr:
