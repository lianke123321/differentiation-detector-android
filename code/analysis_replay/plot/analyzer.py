'''
#######################################################################################################
#######################################################################################################

by: Hyungjoon Koo (hykoo@cs.stonybrook.edu)
    Stony Brook University

Goal: TCP/UDP flow analysis to determine if there is any traffic differentiation from server side

Required package
    (*) dpkt (https://code.google.com/p/dpkt/)

Usage:
    python analyzer.py --proto=[tcp|udp] --abbas=[True|False]

Pre-condition:
    In case of TCP, the script generates throughput, throughput CDF, and RTT CDF in TCP_PCAP_DIR.
	It is required to copy pcap files in TCP_PCAP_DIR in advance.
	In case of UDP, the script generates throughput, throughput CDF, and jitter CDF in UDP_PCAP_DIR.
    It is required to run "udp_jitter_plotready.py" ahead of time to make preparation.
    
Example:
    python analyzer.py --proto=tcp
	python analyzer.py --proto=udp --replaying_dir=./skype
	python analyzer.py --abbas=True

#######################################################################################################
#######################################################################################################
'''

import sys
import os
import ConfigParser
import commands
import subprocess
import operator
import dpkt

DEBUG = 2

# Global variables
PCAP_DIR = '../data/pcaps'
TCP_PCAP_DIR = '../data/pcaps/tcp'
UDP_PCAP_DIR = '../data/pcaps/udp'
PLOT_DIR = '../data/pcaps/generated_plots2'	# Directory where result files reside in
TXT_PCAP_DIR = '../data/pcaps/text_pcaps'	# Directory where tshark output reside in
REPLAYING_PCAP_DIR = '../../server_replay/tshark'
ABBAS_DIR = '../data/pcaps/generated_plots'	# Directory where the result of Abbas code reside in
ABBAS_RUN = '../plot/draw_plots.sh'

# Common generating files during analysis in PLOT_DIR/[file_name]
XPUT_TXT = "xputplot.txt"
XPUT_GRAPH = "xputplot.gp"
XPUT_PLOT = "xputplot.ps"
XPUT_CDF_TXT = "xputplotcdf.txt"
XPUT_CDF_GRAPH = "xputcdfplot.gp"
XPUT_CDF_PLOT = "xputcdfplot.ps"

# Generating files for TCP during analysis in PLOT_DIR/[file_name]
RTT_CDF_TXT = "rttcdfplot.txt"
RTT_CDF_GRAPH = "rttcdfplot.gp"
RTT_CDF_PLOT = "rttcdfplot.ps"

# Generating files for UDP during analysis in PLOT_DIR/[file_name]
SVR_SENT = "server_sent.txt"
SVR_RCVD = "server_rcvd.txt" 
SVR_SENT_INTVL = "server_sent_interval.txt"
SVR_RCVD_INTVL = "server_rcvd_interval.txt"
CLT_SENT_INTVL = "client_sent_interval_rcvd.txt"
CLT_RCVD_INTVL = "client_rcvd_interval_rcvd.txt"
SVR_JITTER = "server_jitter.txt"
CLT_JITTER = "client_jitter.txt"

DEBUG = 0

class Singleton(type):
    _instances = {}
    def __call__(cls, *args, **kwargs):
        if cls not in cls._instances:
            cls._instances[cls] = super(Singleton, cls).__call__(*args, **kwargs)
        return cls._instances[cls]	
		
class Configs(object):
    '''
    This object holds all configs
    
    BE CAREFUL: it's a singleton!
    '''
    __metaclass__ = Singleton
    _Config  = None
    _configs = {}
    def __init__(self, config_file = None):
        self._Config = ConfigParser.ConfigParser()
        self.action_count = 1
        self._maxlen = 0
        if config_file != None:
            read_config_file(config_file)
    def read_config_file(self, config_file):
        self._Config.read(config_file)
        for section in self._Config.sections():
            for option in self._Config.options(section):
                self.set(option, self._Config.get(section, option))
    def read_args(self, args):
        for arg in args[1:]:
            a = ((arg.strip()).partition('--')[2]).partition('=')
            if a[2] in ['True', 'true']:
                self.set(a[0], True)
            elif a[2] in ['False', 'false']:
                self.set(a[0], False)
            else:
                try:
                    self.set(a[0], int(a[2]))
                except ValueError:
                    try:
                        self.set(a[0], float(a[2]))
                    except ValueError:
                        self.set(a[0], a[2])
    def check_for(self, list_of_mandotary):
        try:
            for l in list_of_mandotary:
                self.get(l)
        except:
            print '\nYou should provide \"--{}=[]\"\n'.format(l)
            sys.exit(-1) 
    def get(self, key):
        return self._configs[key]
    def is_given(self, key):
        try:
            self._configs[key]
            return True
        except:
            return False
    def set(self, key, value):
        self._configs[key] = value
        if len(key) > self._maxlen:
            self._maxlen = len(key)
    def show(self, key):
        print key , ':\t', value
    def show_all(self):
        for key in self._configs:
            print '\t', key.ljust(self._maxlen) , ':', self._configs[key]
    def reset_action_count(self):
        self._configs['action_count'] = 0
    def reset(self):
        _configs = {}
        self._configs['action_count'] = 0

def PRINT_ACTION(string, indent, action=True):
    if action:
        print ''.join(['\t']*indent), '[' + str(Configs().action_count) + ']' + string
        Configs().action_count = Configs().action_count + 1
    else:
		print ''.join(['\t']*indent) + string

'''
Throughput analysis for TCP and UDP
'''
def xPutPlot(fileLocation):
	xPutPlotFile = open(fileLocation + '/' + XPUT_GRAPH,'w')
	data = '# Throughtput plot for ' + fileLocation.split('/')[-1] + '\n'
	data += 'set style data lines\n' 
	data += 'set title "Throughput"\n'
	data += 'set key off\n'
	data += 'set xlabel "Time (seconds)"\n'
	data += 'set ylabel "Throughput (KB/s)"\n'
	data += 'set term postscript color eps enhanced "Helvetica" 16\n'
	data += 'set size ratio 0.5\n'
	data += 'set style line 80 lt 0\n'
	data += 'set grid back linestyle 81\n'
	data += 'set border 3 back linestyle 80\n'
	data += 'set xtics nomirror\n'
	data += 'set ytics nomirror\n'
	data += 'set out "' + fileLocation + '/' + XPUT_PLOT + '"\n'
	data += 'plot "' + fileLocation + '/' + XPUT_TXT + '" using 1:($2/1000.0) with lines lw 3\n'
	xPutPlotFile.write(data)
	subprocess.Popen("gnuplot " + fileLocation + "/" + XPUT_GRAPH, shell = True)
	
def xPutAnalyze(file, pcap_dir):
	outDirectory = PLOT_DIR + "/" + file.split('.pcap')[0]
	if os.path.isdir(outDirectory) == False:
		os.mkdir(outDirectory)
	outFile = outDirectory + "/" + XPUT_TXT
	tsharkCmd = "tshark -qz io,stat,0.1 -r " + pcap_dir + "/" + file + " | grep \"<>\" | awk -F'[|<>]' '{print $4, $6*10}' > " + outFile + " 2> /dev/null"
	os.system(tsharkCmd)
	xPutPlot(outDirectory)

'''
Throughput CDF analysis for TCP and UDP
'''
def xPutCDFPlot(fileLocation):
	xPutPlotFile = open(fileLocation + '/' + XPUT_CDF_GRAPH, 'w')
	data = '# Throughtput CDF plot for ' + fileLocation.split('/')[-1] + '\n'
	data += 'set style data lines\n' 
	data += 'set title "Throughput CDF"\n'
	data += 'set key off\n'
	data += 'set xlabel "Time (seconds)"\n'
	data += 'set ylabel "CDF"\n'
	data += 'set term postscript color eps enhanced "Helvetica" 16\n'
	data += 'set size ratio 0.5\n'
	data += 'set style line 80 lt 0\n'
	data += 'set grid back linestyle 81\n'
	data += 'set border 3 back linestyle 80\n'
	data += 'set xtics nomirror\n'
	data += 'set ytics nomirror\n'
	data += 'set out "' + fileLocation + '/' + XPUT_CDF_PLOT + '"\n'
	data += 'countpoints(file) = system( sprintf("grep -v ^# %s| wc -l", file) )\n'
	data += 'pointcount = countpoints("' + fileLocation + '/' + XPUT_CDF_TXT + '")\n'
	data += 'plot "' + fileLocation + '/' + XPUT_CDF_TXT + '" using ($1/1000.0):(1.0/pointcount) smooth cumulative with lines lw 3 linecolor rgb "blue" t "A to B"\n'
	xPutPlotFile.write(data)
	subprocess.Popen("gnuplot " + fileLocation + "/" + XPUT_CDF_GRAPH, shell = True)
	
def xPutCDFAnalyze(file):
	outDirectory = PLOT_DIR + "/" + file.split('.pcap')[0]
	if os.path.isdir(outDirectory) == False:
		os.mkdir(outDirectory)
	outFile = outDirectory + "/" + XPUT_CDF_TXT
	sortXPutCmd = "cat " + outDirectory + "/" + XPUT_TXT + " | sort -n -k2,2 | awk '{print $2}' > " + outFile + " 2> /dev/null"
	os.system(sortXPutCmd)
	xPutCDFPlot(outDirectory)

'''
RTT CDF analysis for TCP
'''
def rttCDFPlot(fileLocation):
	rttPlotFile = open(fileLocation + '/' + RTT_CDF_GRAPH,'w')
	data = '# TCP RTT CDF plot for ' + fileLocation.split('/')[-1] + '\n'
	data += 'set style data lines\n' 
	data += 'set title "RTT CDF"\n'
	data += 'set key bottom right\n'
	data += 'set xlabel "RTT"\n'
	data += 'set ylabel "CDF"\n'
	data += 'set yrange [0:1]\n'
	data += 'set term postscript color eps enhanced "Helvetica" 16\n'
	data += 'set size ratio 0.5\n'
	data += 'set style line 80 lt 0\n'
	data += 'set grid back linestyle 81\n'
	data += 'set border 3 back linestyle 80\n'
	data += 'set xtics nomirror\n'
	data += 'set ytics nomirror\n'
	data += 'set out "' + fileLocation + '/' + RTT_CDF_PLOT + '"\n'
	data += 'a=0\n'
	data += 'cumulative_sum(x)=(a=a+x,a)\n'
	data += 'countpoints(file) = system( sprintf("grep -v ^# %s| wc -l", file) )\n'
	data += 'pointcount = countpoints("' + fileLocation + '/' + RTT_CDF_TXT + '")\n'
	data += 'plot "' + fileLocation + '/' + RTT_CDF_TXT + '" using 1:(1.0/pointcount) smooth cumulative with lines lw 3 linecolor rgb "green" t "A to B"\n'
	rttPlotFile.write(data)
	subprocess.Popen("gnuplot " + fileLocation + "/" + RTT_CDF_GRAPH, shell = True)

def rttCDFAnalyze(file, pcap_dir):
	outDirectory = PLOT_DIR + "/" + file.split('.pcap')[0]
	if os.path.isdir(outDirectory) == False:
		os.mkdir(outDirectory)
	outFile = outDirectory + "/" + RTT_CDF_TXT
	
	textRTTPcap = TXT_PCAP_DIR + "/" + file.split('.pcap')[0] + "_rtt.txt"
	rttCmd = 'tshark -T fields -E header=y -E separator=, -E quote=d -e frame.number -e frame.time_relative -e ip.src -e tcp.srcport -e ip.dst -e tcp.dstport -e tcp.flags -e tcp.analysis.acks_frame -e tcp.analysis.ack_rtt -r "' + pcap_dir + '/' + file + '" > ' + textRTTPcap
	os.system(rttCmd)
	
	pairs = {}
	tcp_rtts = []
	f = open(textRTTPcap,'r')
	allPkts = f.readlines()
	items = allPkts[0].replace('\n','').split(',')
	for line in range(1, (len(allPkts) - 1)):
		client_ip = allPkts[line].replace('\n','').replace('"','').split(',')[2]
		client_port = allPkts[line].replace('\n','').replace('"','').split(',')[3]
		server_ip = allPkts[line].replace('\n','').replace('"','').split(',')[4]
		server_port = allPkts[line].replace('\n','').replace('"','').split(',')[5]
		pkt_keys = client_ip + '-' + client_port + '-' + server_ip + '-' + server_port
		if pkt_keys not in pairs:
			pairs[pkt_keys] = 1
		else:
			pairs[pkt_keys] += 1

	sorted_pair = sorted(pairs.iteritems(), key=operator.itemgetter(1))
	
	if DEBUG == 1:
		print "\tTOP 10 Connections:"
		for i in range(1,11):
			print "\t\t" + str(sorted_pair[len(sorted_pair)-i])
	
	(ip,cnt) = sorted_pair[len(sorted_pair)-1]
	src = ip.split('-')[0]
	dst = ip.split('-')[2]
	
	for line in range(1, (len(allPkts) -1)):
		client_ip = allPkts[line].replace('\n','').replace('"','').split(',')[2]
		client_port = allPkts[line].replace('\n','').replace('"','').split(',')[3]
		server_ip = allPkts[line].replace('\n','').replace('"','').split(',')[4]
		server_port = allPkts[line].replace('\n','').replace('"','').split(',')[5]
		pkt_keys = client_ip + '-' + client_port + '-' + server_ip + '-' + server_port
		rtt = allPkts[line].replace('\n','').replace('"','').split(',')[8]
		if (client_ip == src and server_ip == dst) or (client_ip == dst and server_ip == src):
			if len(rtt) > 0:
				tcp_rtts.append(float(rtt))
	tcp_rtts.sort()
	print str(len(tcp_rtts)) + ' packets! (' + src + ' <---> ' + dst + ')',
	f = open(outFile, 'w')
	for rtt in tcp_rtts:
		f.write(str(rtt*1000) + '\n')
	rttCDFPlot(outDirectory)

'''
Jitter CDF analysis for UDP
'''
def jitterCDFPlot(fileLocation, endpoint):
	jitterPlotFile = open(fileLocation + '/jittercdfplot_' + endpoint + '.gp','w')
	data = '# Sorted jitter on ' + endpoint + ' side\n'
	data += 'set title "UDP Jitter"\n'
	data += 'set style data lines\n' 
	data += 'set key bottom right\n'
	data += 'set ylabel "CDF" font "Courier, 14"\n'
	data += 'set xlabel "Jitter (ms)" font "Courier, 14"\n'
	data += 'set yrange [0:1]\n'
	data += 'set term postscript color eps enhanced "Helvetica" 16\n'
	data += 'set grid back linestyle 81\n'
	data += 'set style line 1 lw 4 lc rgb "#990042"\n'
	data += 'set xtics nomirror\n'
	data += 'set ytics nomirror\n'
	data += 'set out "' + fileLocation + '/jittercdfplot_' + endpoint + '.ps"\n'
	data += 'a=0\n'
	data += 'cumulative_sum(x)=(a=a+x,a)\n'
	data += 'countpoints(file) = system( sprintf("grep -v ^# %s| wc -l", file) )\n'
	data += 'pointcount = countpoints("' + fileLocation + '/' + endpoint + '_jitter_sorted.txt")\n'
	data += 'plot "' + fileLocation + '/' + endpoint + '_jitter_sorted.txt" using 1:(1.0/pointcount) smooth cumulative with lines ls 1\n'
	jitterPlotFile.write(data)
	subprocess.Popen("gnuplot " + fileLocation + "/jittercdfplot_" + endpoint + ".gp", shell = True)
	
def jitterCDFAnalyze(file):
	outDirectory = PLOT_DIR + "/" + file.split('.pcap')[0]
	files = os.listdir(outDirectory)
	if SVR_JITTER and CLT_JITTER in files:
		client_jitter_sort_cmd = ("sort " + outDirectory + '/' + CLT_JITTER + ' > ' + outDirectory + '/' + 'client_jitter_sorted.txt')
		server_jitter_sort_cmd = ("sort " + outDirectory + '/' + SVR_JITTER + ' > ' + outDirectory + '/' + 'server_jitter_sorted.txt')
		os.system(client_jitter_sort_cmd)
		os.system(server_jitter_sort_cmd)
		jitterCDFPlot(outDirectory, 'server')
		jitterCDFPlot(outDirectory, 'client')
	else:
		print "\t\tEither of the following file is missing: " + SVR_JITTER + ' or ' + CLT_JITTER
		sys.exit()

'''
Helper functions to prepare for UDP Jitter CDF analysis
'''
# Extracts two files containing the packets which server sent and which received from client respectively
def splitPcap2(outDir, file_name, client, server):
    split_cs = ("tshark -r \"" + UDP_PCAP_DIR + "/" + file_name + "\" | grep \"" + client + " -> " + server + "\" > " + outDir + "/" + SVR_RCVD)
    os.system(split_cs)
    split_sc = ("tshark -r \"" + UDP_PCAP_DIR + "/" + file_name + "\" | grep \"" + server + " -> " + client + "\" > " + outDir + "/" + SVR_SENT)
    os.system(split_sc)
    
# UDP Jitter calculation
# Si: the timestamp from packet i, 
# Ri: the time of arrival in RTP timestamp units for packet i, 
# J: the interarrival between two packets i and j,
# J(i,j) = (Rj - Ri) - (Sj - Si) = (Rj - Sj) - (Ri - Si)
# Output is in milliseconds
def udpDelay2(outDirectory):
    f1 = open(outDirectory + "/" + CLT_SENT_INTVL, 'r')
    f2 = open(outDirectory + "/" + SVR_RCVD_INTVL, 'r')
    f3 = open(outDirectory + "/" + SVR_SENT_INTVL, 'r')
    f4 = open(outDirectory + "/" + CLT_RCVD_INTVL, 'r')

    interval1 = [line.rstrip() for line in f1]
    interval2 = [line.rstrip() for line in f2]
    interval3 = [line.rstrip() for line in f3]
    interval4 = [line.rstrip() for line in f4]
    
    num_client_sent = len(interval1) + 1
    num_server_rcvd = len(interval2) + 1
    lossRateCS = 100.0 - (float(num_server_rcvd)/float(num_client_sent))*100
    print "\tProcessing delay at server..."
    if lossRateCS < 0:
        print "\t\tLoss Rate = %3.2f%% (%d / %d)" % (lossRateCS, num_server_rcvd, num_client_sent) + "<--WHAT?? SOMETHING IS WRONG!"
    else:
        print "\t\tLoss Rate = %3.2f%% (%d / %d)" % (lossRateCS, num_server_rcvd, num_client_sent)
    print "\t\tClient has sent " + str(num_client_sent) + " UDP packets and",
    print "server has received " + str(num_server_rcvd)+ " UDP packets."

    jiiterAtServer = []
    for x in range(0,len(interval1)-1) if len(interval1) <= len(interval2) else range(0,len(interval2)-1):
        jiiterAtServer.append(format_float(abs(1000*(float(interval2[x])-float(interval1[x]))),15))
    
    f_jiiterAtServer = open(outDirectory + '/' + SVR_JITTER ,'w')
    for delay in range(0, len(jiiterAtServer)):
        f_jiiterAtServer.write(jiiterAtServer[delay]+'\n')
    f1.close()
    f2.close()

    num_server_sent = len(interval3) + 1
    num_client_rcvd = len(interval4) + 1
    lossRateSC = 100.0 - (float(num_client_rcvd)/float(num_server_sent))*100
    print "\tProcessing delay at client..."
    if lossRateSC < 0:
        print "\t\tLoss Rate = %3.2f%% (%d / %d)" % (lossRateSC, num_client_rcvd, num_server_sent) + "<--WHAT?? SOMETHING IS WRONG!"
    else:
        print "\t\tLoss Rate = %3.2f%% (%d / %d)" % (lossRateSC, num_client_rcvd, num_server_sent)
    print "\t\tClient has sent " + str(num_server_sent) + " UDP packets and",
    print "server has received " + str(num_client_rcvd)+ " UDP packets."

    jiiterAtClient = []
    f_jiiterAtClient = open(outDirectory + '/' + CLT_JITTER, 'w')
    for x in range(0,len(interval3)-1) if len(interval3) <= len(interval4) else range(0,len(interval4)-1):
        jiiterAtClient.append(format_float(abs(1000*(float(interval4[x])-float(interval3[x]))),15))

    for delay in range(0, len(jiiterAtClient)):
        f_jiiterAtClient.write(jiiterAtClient[delay]+'\n')
    f3.close()
    f4.close()

def extractEndpoints2(out_dir, file_name):
	extract = ("tshark -Tfields -E separator=- -e ip.src -e ip.dst -r " + UDP_PCAP_DIR + "/" + file_name +" | head -1 > " + out_dir + "/endpoints.txt")
	os.system(extract)
	with open(out_dir + "/endpoints.txt",'r') as f:
		ends = f.read().splitlines()
	f.close()
	return ends[0].split("-")

def parsedPktCnt2(out_dir, file):
	pktCntCmd = ("cat " + out_dir + "/" + file + " " + " | wc -l")
	import commands
	pktCnt = commands.getoutput(pktCntCmd)
	return pktCnt
	
def getTimestamp2(out_dir, file):
	getTimestampCmd = ("cat " + out_dir + "/" + file + " | awk '{print $2}' > " + out_dir + "/" + "ts_" + file + ".tmp")
	os.system(getTimestampCmd)
	
# Saves the inter-packet intervals between when to sent
def interPacketSentInterval2(out_dir, file):
	tmp = open(out_dir + '/ts_' + file + '.tmp','r')
	timestamps = tmp.read().splitlines()
	intervals = []
	i = 0
	ts_cnt = len(timestamps)
	while (i < ts_cnt - 1):
		intervals.append(format_float(float(timestamps[i+1]) - float(timestamps[i]),15))
		i = i + 1
	f = open(out_dir + '/' + file.split('.txt')[0] + '_interval.txt', 'w')
	f.write('\n'.join(str(ts) for ts in intervals))
	os.system('rm -f ' + out_dir + '/ts_' + file + '.tmp')

# Helps to write float format by removing characters
def format_float(value, precision=-1):
    if precision < 0:
        f = "%f" % value
    else:
        f = "%.*f" % (precision, value)
    p = f.partition(".")
    s = "".join((p[0], p[1], p[2][0], p[2][1:].rstrip("0")))
    return s

# Returns the number of packets in a pcap file (pkt_type=[udp|tcp|total|other])
def pkt_ctr(pcap_dir, file_name, pkt_type):
	udp_ctr = 0
	tcp_ctr = 0
	other_ctr = 0
	total_ctr = 0

	filepath = pcap_dir + "/" + file_name
	f = open(filepath)
	for ts, buf in dpkt.pcap.Reader(file(filepath, "rb")):
		 eth = dpkt.ethernet.Ethernet(buf)
		 total_ctr += 1
		 if eth.type == dpkt.ethernet.ETH_TYPE_IP: # 2048
				 ip = eth.data
				 if ip.p == dpkt.ip.IP_PROTO_UDP:  # 17
						 udp_ctr += 1

				 if ip.p == dpkt.ip.IP_PROTO_TCP:  # 6
						 tcp_ctr += 1
		 else:
				 other_ctr += 1

	# Returns the number of packets depending on the type
	if pkt_type == 'total':
		return total_ctr
	elif pkt_type == 'tcp':
		return tcp_ctr
	elif pkt_type == 'udp':
		return udp_ctr
	elif pkt_type == 'other':
		return other_ctr
	else:
		return -1
		
# Generate appropriate files to draw jitter CDF graph
def jitterPlotReady(replaying_dir):
    pcap_files = []
    for pcap_file in os.listdir(REPLAYING_PCAP_DIR):
        if pcap_file.endswith('_out.pcap'):
			outDirectory = PLOT_DIR + "/" + pcap_file.split('.pcap')[0]
			if os.path.isdir(outDirectory) == False:
				os.mkdir(outDirectory)
			pcap_files.append(os.path.abspath('.') + '/' + pcap_file)
			print "\tMoving " + pcap_file + " to " +  UDP_PCAP_DIR
			os.system("mv " + REPLAYING_PCAP_DIR + "/" + pcap_file + " " + UDP_PCAP_DIR + "/" + pcap_file)

    if len(pcap_files) == 0:
        print '\tThe directory "'+ REPLAYING_PCAP_DIR + '" does not contain any "*_out.pcap" file while replaying!'
        sys.exit()
    else:
        (absolute_path, file_name) = os.path.split(pcap_files[0])
		
    # Extracting client/server packets from two endpoints respectively. (IP might be different due to NAT/PAT.)
    if DEBUG == 2: print "\tTarget file: " + file_name
    endpoints = extractEndpoints2(outDirectory, file_name)
    client = endpoints[0]
    server = endpoints[1]
    if DEBUG == 2: print "\t" + "Client: " + client + " <-> Server: " + server + " from server side"
    splitPcap2(outDirectory, file_name, client, server)
    
    # Counting all UDP Packets on server side.
    if DEBUG == 2: print "\t# of UDP packets collected on server side: " + str(pkt_ctr(UDP_PCAP_DIR, file_name, 'udp'))
    
    # Getting the delay from parsed UDP Packets on server side.
    if DEBUG == 2: print "\tThere are " + parsedPktCnt2(outDirectory, SVR_SENT) + " packets which server has successfully sent."
    if DEBUG == 2: print "\tThere are " + parsedPktCnt2(outDirectory, SVR_RCVD) + " packets which server has successfully received."
    
    # Getting inter-packet timestamps UDP Packets on server side.
    getTimestamp2(outDirectory, SVR_SENT)
    interPacketSentInterval2(outDirectory, SVR_SENT)
    print "\t" + SVR_SENT_INTVL + " has been created!"
    getTimestamp2(outDirectory, SVR_RCVD)
    interPacketSentInterval2(outDirectory, SVR_RCVD)
    print "\t" + SVR_RCVD_INTVL + " has been created!"

    # Bring the received file from client.
    os.system("cp " + replaying_dir + "/" + CLT_SENT_INTVL + " " + outDirectory + "/" + CLT_SENT_INTVL)
    os.system("cp " + replaying_dir + "/" + CLT_RCVD_INTVL + " " + outDirectory + "/" + CLT_RCVD_INTVL)
    udpDelay2(outDirectory)


'''
Main Functions to run TCP/UDP analysis
'''
def runTCP():
	files = os.listdir(TCP_PCAP_DIR)
	for file in files:
		if '.' in file:
			if file.split('.')[-1] == "pcap":
				print '\tProcessing "' + file + '"'
				print '\t\tThroughtput ...',
				xPutAnalyze(file, TCP_PCAP_DIR)
				print '...Done!!'
				print '\t\tThroughtput CDF ...',
				xPutCDFAnalyze(file)
				print '...Done!!'
				print '\t\tRTT CDF ...',
				rttCDFAnalyze(file, TCP_PCAP_DIR)
				print '...Done!!'
	print '\tAll generated files have been saved to ' + PLOT_DIR

def runUDP():
	files = os.listdir(UDP_PCAP_DIR)
	for file in files:
		if '.' in file:
			if file.split('.')[-1] == "pcap":
				print '\tProcessing "' + file + '"'
				print '\t\tThroughtput ...',
				xPutAnalyze(file, UDP_PCAP_DIR)
				print '...Done!!'
				print '\t\tThroughtput CDF ...',
				xPutCDFAnalyze(file)
				print '\t\t...Done!!'
				print '\t\tJitter CDF ...',
				jitterCDFAnalyze(file)
				print '...Done!!'
	print '\tAll generated files have been saved to ' + PLOT_DIR

# Check if pcap files are in the pcap directory
def chkPcap(pcap_dir):
	files = os.listdir(pcap_dir)
	numOfFiles = 0
	for file in files:
		if '.' in file:
			if file.split('.')[-1] == "pcap":
				numOfFiles += 1
	if numOfFiles == 0:
		print "\tThere is no pcap file extension in the directory: " + pcap_dir
		sys.exit()

# Check if PLOT_DIR/TCP_PCAP_DIR/UDP_PCAP_DIR exists
def chkEnv(protocol, replaying_dir = None):
	if os.path.isdir(PCAP_DIR) == False:
		os.mkdir(PCAP_DIR)
	if os.path.isdir(PLOT_DIR) == False:
		os.mkdir(PLOT_DIR)
	if os.path.isdir(TXT_PCAP_DIR) == False:
		os.mkdir(TXT_PCAP_DIR)
	if os.path.isdir(TCP_PCAP_DIR) == False:
		os.mkdir(TCP_PCAP_DIR)
	if os.path.isdir(UDP_PCAP_DIR) == False:
		os.mkdir(UDP_PCAP_DIR)

	if protocol == 'tcp':
		chkPcap(TCP_PCAP_DIR) 
	elif protocol == 'udp':
		jitterPlotReady(replaying_dir)
		chkPcap(UDP_PCAP_DIR)
	else:
		print '\tUnexpected Error! Terminated...'
	
def analysisMain():
	PRINT_ACTION('Reading configs file and args...', 0)
	configs = Configs()
	configs.set('abbas', False)
	configs.set('replaying_dir', None)
	configs.read_args(sys.argv)
	configs.show_all()
	replaying_dir = configs.get('replaying_dir')
	
	PRINT_ACTION('Analyzing and drawing plots...', 0)
	if configs.get('abbas') == True:
		print '\tRunning the analysis from Abbas code..'
		copy_pcaps = 'cp ' + TCP_PCAP_DIR + '/*.pcap' + ' ../data/pcaps/'
		os.system(copy_pcaps)
		os.system("bash " + ABBAS_RUN)
		remove_pcaps = 'rm ../data/pcaps/*.pcap' 
		os.system(remove_pcaps)
		print '\tAll generated files have been saved to ' + ABBAS_DIR
	else:
		protocol = configs.get('proto')
		if protocol == 'tcp':
			print '\t[TCP Pcap File Analysis]'
			chkEnv(protocol)
			runTCP()
		elif protocol == 'udp':
			print '\t[UDP Pcap File Analysis]'
			if replaying_dir == None:
				print '\tOption "--replaying_dir" is missing!'
				sys.exit()
			chkEnv(protocol, replaying_dir)
			runUDP()
		else:
			print '\tOops! Provided the protocol which is NOT supported, Terminated...'
			sys.exit()
	
if __name__ == '__main__':
	if len(sys.argv) < 2:
		print "Usage: " + sys.argv[0] + " --proto=[tcp|udp] --abbas=[True|False] --replaying_dir=[]"
		print "\tThis program assumes that there exists *.pcap files in the following:" 
		print "\tTCP: " + TCP_PCAP_DIR + ", UDP: " + UDP_PCAP_DIR
		print "\tIf you use Abbas code, the pcap files will be copied into ../data/pcaps."
		print "\tIf you analyze UDP, the replaying directory should be indicated."
		sys.exit()
	analysisMain()