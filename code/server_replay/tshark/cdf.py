"""@package docstring

by: Arash Molavi Kakhki (arash@ccs.neu.edu)
    Northeastern University
    Dec 2013

"""

import os, sys, subprocess, re, numpy, math, commands, pylab
from decimal import *
import python_lib 
from python_lib import Configs, PRINT_ACTION
from scipy import stats

class DataPoint(object):
    def __init__(self, begin, end, frames, bytes):
        self.begin  = begin
        self.end    = end
        self.frames = frames
        self.bytes  = bytes
        self.xput   = (bytes/(end-begin))/1000
    def show(self):
        print 'begin :', self.begin
        print 'end   :', self.end
        print 'frames:', self.frames
        print 'bytes :', self.bytes
        print 'xput  :', self.xput
class DumpStat(object):
    def __init__(self, xput_min, xput_max, xput_median, xput_avg, xput_std, name=None):
        self.name        = name
        self.xput_min    = xput_min
        self.xput_max    = xput_max
        self.xput_median = xput_median
        self.xput_avg    = xput_avg
        self.xput_std    = xput_std
    def show(self, row=False):
        if row:
            return str(self.xput_min) + '\t' + str(self.xput_max) + '\t' + str(self.xput_median) + '\t' + str(self.xput_avg) + '\t' + str(self.xput_std)
        else:
            print 'name:', self.name
            print '\txput_min   :', self.xput_min
            print '\txput_max   :', self.xput_max
            print '\txput_median:', self.xput_median
            print '\txput_avg   :', self.xput_avg
            print '\txput_std   :', self.xput_std
    def two_decimal(self):
        self.xput_min    = math.ceil(self.xput_min*100)/100
        self.xput_max    = math.ceil(self.xput_max*100)/100
        self.xput_median = math.ceil(self.xput_median*100)/100
        self.xput_avg    = math.ceil(self.xput_avg*100)/100
        self.xput_std    = math.ceil(self.xput_std*100)/100
def dumpstat_avg(list_of_DumpStat, name=None):
    min_avg    = numpy.average([dumpstat.xput_min for dumpstat in list_of_DumpStat])
    max_avg    = numpy.average([dumpstat.xput_max for dumpstat in list_of_DumpStat])
    median_avg = numpy.average([dumpstat.xput_median for dumpstat in list_of_DumpStat])
    avg_avg    = numpy.average([dumpstat.xput_avg for dumpstat in list_of_DumpStat])
    std_avg    = numpy.average([dumpstat.xput_std for dumpstat in list_of_DumpStat])
    return DumpStat(min_avg, max_avg, median_avg, avg_avg, std_avg, name) 
def parse_output(output):
    data_points = []
    lines = output.splitlines()
    for l in lines:
        try:
            parsed = map(lambda x: float(x), re.split(r'<>|\|', l.replace(' ', ''))[1:-1])
        except:
            continue
        if len(parsed) == 4:
            if parsed[0] == parsed[1]:
                'Done!', parsed[0], parsed[1]
                break
            data_points.append(DataPoint(*parsed))
    return data_points
def run(pcap_file):
    PRINT_ACTION('Reading configs file and args)', 0)
    configs = Configs()
    
    '''Defaults'''
    interval = 1
    

    p = subprocess.Popen(['tshark', '-qz', ('io,stat,' + str(interval)), '-r', pcap_file], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    output, err = p.communicate()

    if err:
        print 'Error!{}'.format(err)
    
    data_points = parse_output(output)

    xputs = [d.xput for d in data_points]
    xputs.sort()
    
    return xputs
def sorted_list_to_cdf(xput, outfile='cdf.txt'):
    x = []
    y = []
    for i in range(len(xput)):
        x.append(xput[i])
        y.append(float(i)/len(xput))
    return x, y
def split_list(mylist, *args):
    ilist = map(lambda p : int(p * len(mylist) / 100.0), args) + [len(mylist)]
    return reduce(lambda l, v : [l[0] + [mylist[l[1]:v]], v], ilist, [[],0])[0]    
def do_dir(dir):
    res = {}
    dir_path = os.path.abspath(dir)
    print dir_path
    files    = os.listdir(dir_path)
    for file in files:
        if file.endswith(".pcap"):
            xput = run(file)
def main():
    if (sys.argv[1]).endswith(".pcap"):
        filename = os.path.abspath(sys.argv[1])
        xput = run(filename)
        x, y = sorted_list_to_cdf(xput)
        print x
        print y
        pylab.plot(x, y)
        pylab.show()
    elif os.path.isdir(os.path.abspath(sys.argv[1])):
        dir = sys.argv[1]
        res = do_dir(dir)
        ks = 0
        pv = 0
        for r in res:
            ks += res[r][0]
            pv += res[r][1]
            print r, ':', res[r]
        print ks/len(res), '\t', pv/len(res)
    
if __name__=="__main__":
    main()