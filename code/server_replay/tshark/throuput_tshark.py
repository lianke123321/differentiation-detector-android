"""@package docstring

by: Arash Molavi Kakhki (arash@ccs.neu.edu)
    Northeastern University
    Dec 2013
    
USAGE:  python throughput_tshark.py pcap_file=[] interval=[] outfile=[]

        pcap_file: the file you want to analyze. This input is mandotory
        interval : the interval size for calculating throughput (in seconds)
                   default: 1 second
        outfile  : name of the output file. Format is "interval [tab] throughput"
                   default is xput.txt
                   throughput is in bytes/second
        statsfile
"""

import os, sys, subprocess, re, numpy, math, commands
from decimal import *
import python_lib 
from python_lib import Configs, PRINT_ACTION

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
def run(args, plot=False):
    PRINT_ACTION('Reading configs file and args)', 0)
    configs = Configs()
    
    '''Defaults'''
    configs.set('interval', 1)
    configs.set('outfile'  , 'xput.txt')
    configs.set('statsfile', 'stats.txt')
    
    '''Command line arguments'''
    python_lib.read_args(args, configs)

    try:
        configs.get('pcap_file')
    except:
        print "USAGE: python throughput_tshark.py pcap_file=[]"
        print 'You MUST give a pcap_file as input'
        sys.exit(-1)
    
    p = subprocess.Popen(['tshark', '-qz', ('io,stat,' + str(configs.get('interval'))), '-r', configs.get('pcap_file')], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    output, err = p.communicate()

    if err:
        print 'Error!{}'.format(err)
    
    data_points = parse_output(output)
    
    
#    xputs = [d.xput for d in data_points]
#    for x in xputs:
#        print x

    f = open('for_plot.txt', 'w')
    xputs = []
    for d in data_points:
        if d.xput > 10 * 1.5: #ignore intervals with less than 10 packets per second
            xputs.append(d.xput)
            f.write((str(d.end) + '\t' + str(d.xput) + '\n'))
    f.close()

    xputs.sort()
    xputs = split_list(xputs, 25, 75)[1]

    return DumpStat(numpy.min(xputs, axis=0) , numpy.max(xputs, axis=0)
                  , numpy.median(xputs, axis=0), numpy.average(xputs, axis=0)
                  , numpy.std(xputs, axis=0)
                  , configs.get('pcap_file'))
def split_list(mylist, *args):
    ilist = map(lambda p : int(p * len(mylist) / 100.0), args) + [len(mylist)]
    return reduce(lambda l, v : [l[0] + [mylist[l[1]:v]], v], ilist, [[],0])[0]    
def do_dir(dir):
    vpn_noen = []
    vpn_en   = []
    novpn    = []
    dir_path = os.path.abspath(dir)
    for file in os.listdir(os.path.abspath(dir)):
        if file.endswith(".pcap"):
            filename = dir_path + '/' + file
            xput = run(['pcap_file='+filename])
            if '_novpn_' in file:
                novpn.append(xput)
            elif '_vpn_' in file:
                vpn_en.append(xput)
            elif 'tcpdump-' in file:
                vpn_noen.append(xput)
    return dumpstat_avg(novpn, 'novpn'), dumpstat_avg(vpn_en, 'vpn_en'), dumpstat_avg(vpn_noen, 'vpn_noen')
def main():
#    (status, out) = commands.getstatusoutput('tshark -r ~/Desktop/data/dbd_replay/dump_novpn_1_2013-Dec-08-01-30-22.pcap -R "tcp.analysis.ack_rtt" -e tcp.analysis.ack_rtt -T fields -E separator=, -E quote=d')
#    res = []
#    for l in out.splitlines():
#        try:
#            res.append(float(l[1:-1]))
#        except:
#            pass
#    print numpy.average(res, axis = 0)
    
    if (sys.argv[1]).endswith(".pcap"):
        filename = os.path.abspath(sys.argv[1])
        xput = run(['pcap_file='+filename])
        stat = dumpstat_avg([xput])
        stat.two_decimal()
        print 'min\tmax\tmedian\taverage\tstd'
        print stat.show(True)
        
    elif os.path.isdir(os.path.abspath(sys.argv[1])):
        dir = sys.argv[1]
        
        outfile = 'xput_' + os.path.basename(os.path.abspath(dir)) + '.txt'
        print outfile
        novpn, vpn_en, vpn_noen = do_dir(dir)
        novpn.two_decimal()
        vpn_en.two_decimal()
        vpn_noen.two_decimal()
        
        f = open(outfile, 'w')
        f.write('exp\tmin\tmax\tmedian\taverage\tstd\tstd_perc\n')
        f.write( ('novpn\t' + novpn.show(True) + '\t' + str(math.ceil((novpn.xput_std/novpn.xput_avg)*100*100)/100) + '\n') )
        f.write( ('vpn_en\t' + vpn_en.show(True) + '\t' + str(math.ceil((vpn_en.xput_std/vpn_en.xput_avg)*100*100)/100) + '\n') )
        f.write( ('vpn_noen\t' + vpn_noen.show(True) + '\t' + str(math.ceil((vpn_noen.xput_std/vpn_noen.xput_avg)*100*100)/100) + '\n') )
        f.close()
        
        print 'exp\tmin\tmax\tmedian\taverage\tstd\tstd_perc'
        
        print 'novpn\t', novpn.show(True), math.ceil((novpn.xput_std/novpn.xput_avg)*100*100)/100
        print 'vpn_en\t', vpn_en.show(True), math.ceil((vpn_en.xput_std/vpn_en.xput_avg)*100*100)/100
        print 'vpn_noen\t', vpn_noen.show(True), math.ceil((vpn_noen.xput_std/vpn_noen.xput_avg)*100*100)/100
    else:
        print 'The input should be either a .pcap file or a dir with .pcap files in it.'
    
if __name__=="__main__":
    main()