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
"""

import os, sys, subprocess, re
import python_lib 
from python_lib import Configs, PRINT_ACTION

class DataPoint(object):
    def __init__(self, begin, end, frames, bytes):
        self.begin  = begin
        self.end    = end
        self.frames = frames
        self.bytes  = bytes
        self.xput   = bytes/(end-begin)
    def show(self):
        print 'begin :', self.begin
        print 'end   :', self.end
        print 'frames:', self.frames
        print 'bytes :', self.bytes
        print 'xput  :', self.xput
def parse_output(output):
    data_points = []
    lines = output.splitlines()
    for l in lines:
        try:
            parsed = map(lambda x: float(x), re.findall(r"[\w']+", l))
        except:
            continue
        if len(parsed) == 4:
            if parsed[0] == parsed[1]:
                'Done!', parsed[0], parsed[1]
                break
            data_points.append(DataPoint(*parsed))
    return data_points
def run(args):
    PRINT_ACTION('Reading configs file and args)', 0)
    configs = Configs()
    
    '''Defaults'''
    configs.set('interval', 1)
    configs.set('outfile', 'xput.txt')
    
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
        sys.exit(-1)
    
    data_points = parse_output(output)
    
    f = open(configs.get('outfile'), 'w')
    for d in data_points:
        f.write((str(d.end) + '\t' + str(d.xput) + '\n'))
        
def main():
    run(sys.argv)

if __name__=="__main__":
    main()