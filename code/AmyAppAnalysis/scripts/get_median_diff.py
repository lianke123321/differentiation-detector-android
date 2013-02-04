
from datetime import datetime,timedelta
import  sys,  os
import re

def getAverage(file):
  olddate = ''
  date = ''
  difference = timedelta(microseconds=0)
  count = 0
  #outputname = 'output/out' + str(count) + '.txt'
  #outfile = open(outputname, 'w')
  #outfile.write('Remember to clear out all files in this directory!')
  for line in open(file, 'r').readlines():
    l = line.strip().split()
    if len(l) == 0:
      continue
    date = l[0].strip().split('-')    
    year = int(date[0])
    month = int(date[1])
    day = int(date[2])

    l = l[1].strip().split(':')
    hour = int(l[0])
    minutes = int(l[1])
    seconds = l[2]
    seconds = seconds.strip().split('.')
    microseconds = int(seconds[1])
    seconds = int(seconds[0])
    
    date = datetime(year, month, day, hour, minutes, seconds, microseconds)
    if (olddate != ''):    
      delta = date - olddate
 #       print delta 
      difference = difference + delta

 #   print "date", date, "olddate", olddate
 
    olddate = date
    count = count + 1
  difference /= count
  print "Average time:", difference

def getMedian(file):
  difflist = []
  date = ''
  olddate = ''
  #difference = timedelta(microseconds=0)
  count = 0
  #outputname = 'output/out' + str(count) + '.txt'
  outfile = open(file+'.timediffs', 'w')
  #outfile.write('Remember to clear out all files in this directory!')
  for line in open(file, 'r').readlines():
    l = line.strip().split()
    if len(l) == 0:
      continue
    date = l[0].strip().split('-')    
    year = int(date[0])
    month = int(date[1])
    day = int(date[2])

    l = l[1].strip().split(':')
    hour = int(l[0])
    minutes = int(l[1])
    seconds = l[2]
    seconds = seconds.strip().split('.')
    microseconds = int(seconds[1])
    seconds = int(seconds[0])
    
    date = datetime(year, month, day, hour, minutes, seconds, microseconds)
    if (olddate != ''):    
      delta = date - olddate
 #       print delta 
      difflist += [delta]
      outfile.write(str(delta)+'\n')
    olddate = date
    count = count + 1
  difflist.sort()
  print "Median Time:", difflist[int(count/2)]

def run():
  filename = sys.argv[1]
  getAverage(filename)
  getMedian(filename)

if __name__ == '__main__':
    run()
