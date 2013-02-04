#!/usr/bin/env python

import datetime
import os

rootDir = r'C:\Backup\INRIA\Research\Meddle\code\pushNotification\Traces'
expeList = ['iphone_wifi_3g_unplug_novpn', 'iphone_wifi_3g_unplug_vpn', 
            'iphone_wifi_3g_unplug_novpn_run2', 'iphone_wifi_unplug_vpn', 
            'iphone_wifi_unplug_novpn', 'iphone_wifi_3g_unplug_vpn_run2',
            'iphone_wifi_3g_plug_novpn','iphone_wifi_3g_plug_vpn']

for expeName in expeList:
    f = open(os.path.join(rootDir, expeName + '.txt' ), 'r')
    dumpInterTs = open(os.path.join(rootDir, expeName + '_interTs.txt'), 'w')
    dumpTs = open(os.path.join(rootDir,expeName + '_Ts.txt'), 'w')

    timestampNext = 0
    firstTimestamp = 1
    previousTimestamp = 0 

    #inter arrivals
    interTsList = []
    #arrival times
    tsList = []

    for line in f:
        #print line
        #raw_input()
        if line[0:6] == "+-----":
            timestampNext = 1
        elif timestampNext == 1:
            timestampNext = 0
            tmp = line.split()[0].strip().split(':')
            hour = tmp[0]
            minute = tmp[1]

            tmp2 = tmp[2].split(',')
            second = tmp2[0]
            microsecond = ''.join([tmp2[1], tmp2[2]])
            ts  = int(hour) * 60 * 60 + int(minute) * 60 + int(second) +  float('0.' + microsecond)
            if firstTimestamp:
                previousTimestamp = ts
                initialTimestamp = ts
                firstTimestamp = 0
                continue
            interTsList.append(ts - previousTimestamp)
            tsList.append(ts - initialTimestamp)
            previousTimestamp = ts

    #tsList = [i for i in tsList if i > 0.1]
    interTsList = [i for i in interTsList if i > 2]

    for line in interTsList:
        dumpInterTs.write(str(line) + '\n')

    for line in tsList:
        dumpTs.write(str(line) + '\n')
