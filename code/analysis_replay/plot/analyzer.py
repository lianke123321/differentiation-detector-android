'''
#######################################################################################################
#######################################################################################################
Last Updated: Sep 9, 2014

By: Hyungjoon Koo (hykoo@cs.stonybrook.edu)
	Stony Brook University

Goal: TCP/UDP flow analysis to determine if there is any traffic differentiation from server side

Required package
	(*) dpkt (https://code.google.com/p/dpkt/)

Usage:
	python analyzer.py --proto=[tcp|udp] --multiplot=[True|False] --kstest=[True|False]

Pre-condition:
	In case of TCP, the script generates throughput, throughput CDF, and RTT CDF in TCP_PCAP_DIR.
	It is required to copy pcap files in TCP_PCAP_DIR in advance.
	In case of UDP, the script generates throughput, throughput CDF, and jitter CDF in UDP_PCAP_DIR.
		For UDP jitter, it is required to have CLT_SENT_INTVL and CLT_RCVD_INTVL in PLOT_DIR/[pcap_name].
		CLT_SENT_INTVL and CLT_RCVD_INTVL will be collected and sent by udp_client.py while replaying with the option --jitter=True
	
Example:
	python analyzer.py --proto=tcp --multiplot=True --kstest=True
	python analyzer.py --proto=udp --replaying_dir=./skype 

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
import array

try:
	import rpy2.robjects as robjects
	from rpy2.robjects.packages import importr
	from rpy2.robjects.functions import SignatureTranslatedFunction
except:
	pass
	
DEBUG = 0

# Global variables
PCAP_DIR = '../data/pcaps'
TCP_PCAP_DIR = '../data/pcaps/tcp'
UDP_PCAP_DIR = '../data/pcaps/udp'
PLOT_DIR = '../data/pcaps/generated_plots2'	# Directory where result files reside in
TXT_PCAP_DIR = '../data/pcaps/text_pcaps'	# Directory where tshark output reside in
REPLAYING_PCAP_DIR = '../../server_replay/tshark'
# ABBAS_DIR = '../data/pcaps/generated_plots'	# Directory where the result of Abbas code reside in
# ABBAS_RUN = '../plot/draw_plots.sh'
ENDPOINTS = 'endpoints.txt'

# Common generating files during analysis in PLOT_DIR/[file_name]
XPUT_TXT = "xputplot.txt"
XPUT_GRAPH = "xputplot.gp"
XPUT_PLOT = "xputplot.ps"
XPUT_CDF_TXT = "xputplotcdf.txt"
XPUT_CDF_GRAPH = "xputcdfplot.gp"
XPUT_CDF_PLOT = "xputcdfplot.ps"
XPUT_CDF_MULTI_GRAPH = "xputcdfmultiplot.gp"
XPUT_CDF_MULTI_PLOT = "xputcdfmultiplot.ps"
STATS_TXT = "stats.txt"
PKT_CDF_GRAPH = "pktcdfplot.gp"
PKT_CDF_PLOT = "pktcdfplot.ps"
PKT_SIZE_CDF_MULTI_GRAPH = "pktcdfmultiplot.gp"
PKT_SIZE_CDF_MULTI_PLOT = "pktcdfmultiplot.ps"

# Generating common files for TCP during analysis in PLOT_DIR/[file_name]
RTT_CDF_TXT = "rttcdfplot.txt"
RTT_CDF_GRAPH = "rttcdfplot.gp"
RTT_CDF_PLOT = "rttcdfplot.ps"
RTT_CDF_MULTI_GRAPH = "rttcdfmultiplot.gp"
RTT_CDF_MULTI_PLOT = "rttcdfmultiplot.ps"
SVR_PKT_CDF_TXT = "server_pktcdfplot.txt"

# Generating common files for UDP during analysis in PLOT_DIR/[file_name]
SVR_SENT = "server_sent.txt"
SVR_RCVD = "server_rcvd.txt" 
SVR_SENT_INTVL = "server_sent_interval.txt"
SVR_RCVD_INTVL = "server_rcvd_interval.txt"
CLT_SENT_INTVL = "client_sent_interval_rcvd.txt"
CLT_RCVD_INTVL = "client_rcvd_interval_rcvd.txt"
SVR_JITTER = "server_jitter.txt"
CLT_JITTER = "client_jitter.txt"
SVR_JITTER_SORTED = "server_jitter_sorted.txt"
CLT_JITTER_SORTED = "client_jitter_sorted.txt"
JITTER_CDF_GRAPH = "jittercdfplot.gp"
JITTER_CDF_PLOT = "jittercdfplot.ps"
JITTER_CDF_MULTI_GRAPH_CLT = "jittercdfmultiplot_client.gp"
JITTER_CDF_MULTI_PLOT_CLT = "jittercdfmultiplot_client.ps"
JITTER_CDF_MULTI_GRAPH_SVR = "jittercdfmultiplot_server.gp"
JITTER_CDF_MULTI_PLOT_SVR = "jittercdfmultiplot_server.ps"
SVR_RCVD_PKT_CDF_TXT = "server_rcvd_pktcdfplot.txt"
SVR_SENT_PKT_CDF_TXT = "server_sent_pktcdfplot.txt"

# Generating KS-Test files using R
KS_ORIGINAL_FILE = "server_jitter_sorted1.txt"
KS_COMPARED_FILE = "server_jitter_sorted2.txt"
KS_RESULT_PS = "ks_result.ps"
KS_RESULT_TXT = "ks_result.txt"
R_FILE = "ks_test.R"
R_COMMAND = "Rscript"

DEBUG = 0

'''
Basic classes and functions from Arash code
'''
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
	#data += 'plot "' + fileLocation + '/' + XPUT_TXT + '" using 1:($2/1000.0) with lines lw 3\n'
	data += 'plot "' + fileLocation + '/' + XPUT_TXT + '" using 1:($2/1.0) with lines lw 3\n'
	xPutPlotFile.write(data)
	xPutPlotFile.close()
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
	file_name = fileLocation.split("/")[-1]
	xPutPlotFile = open(fileLocation + '/' + XPUT_CDF_GRAPH, 'w')
	data = '# Throughtput CDF plot for ' + fileLocation.split('/')[-1] + '\n'
	data += 'set style data lines\n' 
	data += 'set title "Throughput CDF (' + file_name.replace('_','-') + ')"\n'
	data += 'set key off\n'
	data += 'set xlabel "Throughput (KB/s)"\n'
	data += 'set ylabel "CDF"\n'
	data += 'set yrange [0:1]\n'
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
	#data += 'plot "' + fileLocation + '/' + XPUT_CDF_TXT + '" using ($1/1000.0):(1.0/pointcount) smooth cumulative with lines lw 3 linecolor rgb "blue" t "A to B"\n'
	data += 'plot "' + fileLocation + '/' + XPUT_CDF_TXT + '" using ($1/1.0):(1.0/pointcount) smooth cumulative with lines lw 3 linecolor rgb "blue" t "A to B"\n'
	xPutPlotFile.write(data)
	xPutPlotFile.close()
	subprocess.Popen("gnuplot " + fileLocation + "/" + XPUT_CDF_GRAPH, shell = True)
	
def xPutCDFAnalyze(file):
	outDirectory = PLOT_DIR + "/" + file.split('.pcap')[0]
	if os.path.isdir(outDirectory) == False:
		os.mkdir(outDirectory)
	outFile = outDirectory + "/" + XPUT_CDF_TXT
	sortXPutCmd = "cat " + outDirectory + "/" + XPUT_TXT + " | sort -n -k2,2 | awk '{print $2/1000}' > " + outFile + " 2> /dev/null"
	os.system(sortXPutCmd)
	xPutCDFPlot(outDirectory)

'''
Multiplot - Throughtput CDF for multiple cases (Up to 10)
'''
def generateXputCDFMultiplot(numOfPlots):
	if numOfPlots > 10:
		print "\tThe Multiplot graph supports drawing up to 10\n"
		sys.exit()
	
	entriesTocompare = os.listdir(PLOT_DIR)
	if(len(entriesTocompare) == 0):
		print "\tThere is no generated plot to compare with\n"
	
	print "\t\t* Throughput CDF Multiplot (" + str(numOfPlots) + ")"
	
	#color = ['blue', 'green', 'red', 'black']
	color = ['#330000', '#FF0000', '#009900', '#003366', '#4C0099', '#404040', '#660000', '#000066', '#808080','#0080FF']
	xputMultiplotFile = open('./' + XPUT_CDF_MULTI_GRAPH, 'w')
	data = '# TCP RTT CDF Multiplot Graph \n'
	data += 'set style data lines\n' 
	data += 'set title "Throughtput CDF Comparison"\n'
	data += 'set key bottom right\n'
	data += 'set xlabel "Throughput (KB/s)"\n'
	data += 'set ylabel "CDF"\n'
	data += 'set yrange [0:1]\n'
	data += 'set term postscript color eps enhanced "Helvetica" 16\n'
	data += 'set size ratio 0.5\n'
	data += 'set style line 80 lt 0\n'
	data += 'set grid back linestyle 81\n'
	data += 'set border 3 back linestyle 80\n'
	data += 'set xtics nomirror\n'
	data += 'set ytics nomirror\n'
	data += 'set out "' + './' + XPUT_CDF_MULTI_PLOT + '"\n'
	data += 'a=0\n'
	data += 'cumulative_sum(x)=(a=a+x,a)\n'
	data += 'countpoints(file) = system( sprintf("grep -v ^# %s| wc -l", file) )\n'
	
	i = 0
	for entry in entriesTocompare:
		data += 'pointcount' + str(i) + ' = countpoints("' + PLOT_DIR + '/' + entry + '/' + XPUT_CDF_TXT + '")\n'
		i = i + 1
	
	data += 'plot '
	j = 0
	while j < len(entriesTocompare) - 1:
		data += '"' + PLOT_DIR + '/' + entriesTocompare[j] + '/' + XPUT_CDF_TXT + '" using ($1/1.0):(1.0/pointcount' + str(j) + ') smooth cumulative with lines lw 3 linecolor rgb "' + color[j % len(color)] + '" t "' + entriesTocompare[j].replace('_','-') + '", '
		j = j + 1
	data += '"' + PLOT_DIR + '/' + entriesTocompare[j] + '/' + XPUT_CDF_TXT + '" using ($1/1.0):(1.0/pointcount' + str(j) + ') smooth cumulative with lines lw 3 linecolor rgb "' + color[j % len(color)] + '" t "' + entriesTocompare[j].replace('_','-') + '"\n'
	
	xputMultiplotFile.write(data)
	xputMultiplotFile.close()
	subprocess.Popen("gnuplot ./" + XPUT_CDF_MULTI_GRAPH, shell = True)
	
'''
RTT CDF analysis for TCP
'''
def rttCDFPlot(fileLocation):
	file_name = fileLocation.split("/")[-1]
	rttPlotFile = open(fileLocation + '/' + RTT_CDF_GRAPH, 'w')
	data = '# TCP RTT CDF plot for ' + fileLocation.split('/')[-1] + '\n'
	data += 'set style data lines\n' 
	data += 'set title "RTT CDF (' + file_name.replace('_','-') + ')"\n'
	data += 'set key bottom right\n'
	data += 'set xlabel "RTT (ms)"\n'
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
	rttPlotFile.close()
	subprocess.Popen("gnuplot " + fileLocation + "/" + RTT_CDF_GRAPH, shell = True)

def rttCDFAnalyze(file, pcap_dir):
	outDirectory = PLOT_DIR + "/" + file.split('.pcap')[0]
	if os.path.isdir(outDirectory) == False:
		os.mkdir(outDirectory)
	outFile = outDirectory + "/" + RTT_CDF_TXT
	
	textRTTPcap = TXT_PCAP_DIR + "/" + file.split('.pcap')[0] + "_rtt.txt"
	rttCmd = 'tshark -Tfields -E header=y -E separator=, -E quote=d -e frame.number -e frame.time_relative -e ip.src -e tcp.srcport -e ip.dst -e tcp.dstport -e tcp.flags -e tcp.analysis.acks_frame -e tcp.analysis.ack_rtt -e tcp.len -r "' + pcap_dir + '/' + file + '" > ' + textRTTPcap
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
	f.close()
	rttCDFPlot(outDirectory)

'''
Multiplot - RTT CDF for multiple cases (Up to 10)
'''
def generateRTTCDFMultiplot(numOfPlots):
	if numOfPlots > 10:
		print "\tThe Multiplot graph supports drawing up to 10\n"
		sys.exit()
	
	entriesTocompare = os.listdir(PLOT_DIR)
	if(len(entriesTocompare) == 0):
		print "\tThere is no generated plot to compare with\n"
	
	print "\t\t* RTT CDF Multiplot (" + str(numOfPlots) + ")"
	
	#color = ['blue', 'green', 'red', 'black']
	color = ['#330000', '#FF0000', '#009900', '#003366', '#4C0099', '#404040', '#660000', '#000066', '#808080','#0080FF']
	rttMultiplotFile = open('./' + RTT_CDF_MULTI_GRAPH, 'w')
	data = '# TCP RTT CDF Multiplot Graph \n'
	data += 'set style data lines\n' 
	data += 'set title "RTT CDF Comparison"\n'
	data += 'set key bottom right\n'
	data += 'set xlabel "RTT (ms)"\n'
	data += 'set ylabel "CDF"\n'
	data += 'set yrange [0:1]\n'
	data += 'set term postscript color eps enhanced "Helvetica" 16\n'
	data += 'set size ratio 0.5\n'
	data += 'set style line 80 lt 0\n'
	data += 'set grid back linestyle 81\n'
	data += 'set border 3 back linestyle 80\n'
	data += 'set xtics nomirror\n'
	data += 'set ytics nomirror\n'
	data += 'set out "' + './' + RTT_CDF_MULTI_PLOT + '"\n'
	data += 'a=0\n'
	data += 'cumulative_sum(x)=(a=a+x,a)\n'
	data += 'countpoints(file) = system( sprintf("grep -v ^# %s| wc -l", file) )\n'
	
	i = 0
	for entry in entriesTocompare:
		data += 'pointcount' + str(i) + ' = countpoints("' + PLOT_DIR + '/' + entry + '/' + RTT_CDF_TXT + '")\n'
		i = i + 1
	
	data += 'plot '
	j = 0
	while j < len(entriesTocompare) - 1:
		data += '"' + PLOT_DIR + '/' + entriesTocompare[j] + '/' + RTT_CDF_TXT + '" using 1:(1.0/pointcount' + str(j) + ') smooth cumulative with lines lw 3 linecolor rgb "' + color[j % len(color)] + '" t "' + entriesTocompare[j].replace('_','-') + '", '
		j = j + 1
	data += '"' + PLOT_DIR + '/' + entriesTocompare[j] + '/' + RTT_CDF_TXT + '" using 1:(1.0/pointcount' + str(j) + ') smooth cumulative with lines lw 3 linecolor rgb "' + color[j % len(color)] + '" t "' + entriesTocompare[j].replace('_','-') + '"\n'
	
	rttMultiplotFile.write(data)
	rttMultiplotFile.close()
	subprocess.Popen("gnuplot ./" + RTT_CDF_MULTI_GRAPH, shell = True)
	
'''
Jitter CDF analysis for UDP
'''
def jitterCDFPlot(fileLocation, endpoint):
	color = ['#990042']
	file_name = fileLocation.split("/")[-1]
	jitterPlotFile = open(fileLocation + '/jittercdfplot_' + endpoint + '.gp','w')
	data = '# Sorted jitter on ' + endpoint + ' side\n'
	data += 'set title "UDP Jitter(' + file_name.replace('_','-') + ')"\n'
	data += 'set style data lines\n' 
	data += 'set key bottom right\n'
	data += 'set ylabel "CDF" font "Courier, 14"\n'
	data += 'set xlabel "Jitter (ms)" font "Courier, 14"\n'
	data += 'set xrange [-150:150]\n'
	data += 'set yrange [0:1]\n'
	data += 'set term postscript color eps enhanced "Helvetica" 16\n'
	data += 'set grid back linestyle 81\n'
	data += 'set xtics nomirror\n'
	data += 'set ytics nomirror\n'
	data += 'set out "' + fileLocation + '/jittercdfplot_' + endpoint + '.ps"\n'
	data += 'a=0\n'
	data += 'cumulative_sum(x)=(a=a+x,a)\n'
	data += 'countpoints(file) = system( sprintf("grep -v ^# %s| wc -l", file) )\n'
	data += 'pointcount = countpoints("' + fileLocation + '/' + endpoint + '_jitter_sorted.txt")\n'
	if endpoint == 'client':
		data += 'plot "' + fileLocation + '/' + endpoint + '_jitter_sorted.txt" using 1:(1.0/pointcount) smooth cumulative with lines lw 3 linecolor rgb "' + color[0] + '" t "' + endpoint + ' to server"'
	else:
		data += 'plot "' + fileLocation + '/' + endpoint + '_jitter_sorted.txt" using 1:(1.0/pointcount) smooth cumulative with lines lw 3 linecolor rgb "' + color[0] + '" t "' + endpoint + ' to client"'
	jitterPlotFile.write(data)
	jitterPlotFile.close()
	subprocess.Popen("gnuplot " + fileLocation + "/jittercdfplot_" + endpoint + ".gp", shell = True)
	
def jitterCDFPlotAll(fileLocation):
	color = ['blue', 'green']
	file_name = fileLocation.split("/")[-1]
	jitterPlotFile = open(fileLocation + '/' + JITTER_CDF_GRAPH, 'w')
	data = '# Sorted jitter\n'
	data += 'set title "UDP Jitter (' + file_name.replace('_','-') + ')"\n'
	data += 'set style data lines\n' 
	data += 'set key bottom right\n'
	data += 'set ylabel "CDF" font "Courier, 14"\n'
	data += 'set xlabel "Jitter (ms)" font "Courier, 14"\n'
	data += 'set xrange [-150:150]\n'
	data += 'set yrange [0:1]\n'
	data += 'set term postscript color eps enhanced "Helvetica" 16\n'
	data += 'set grid back linestyle 81\n'
	data += 'set xtics nomirror\n'
	data += 'set ytics nomirror\n'
	data += 'set out "' + fileLocation + '/' + JITTER_CDF_PLOT + '"\n'
	data += 'a=0\n'
	data += 'cumulative_sum(x)=(a=a+x,a)\n'
	data += 'countpoints(file) = system( sprintf("grep -v ^# %s| wc -l", file) )\n'
	data += 'pointcount1 = countpoints("' + fileLocation + '/' + CLT_JITTER_SORTED + '")\n'
	data += 'pointcount2 = countpoints("' + fileLocation + '/' + SVR_JITTER_SORTED + '")\n'
	data += 'plot "' + fileLocation + '/' + CLT_JITTER_SORTED + '" using 1:(1.0/pointcount1) smooth cumulative with lines lw 3 linecolor rgb "' + color[0] + '" t "client to server", '
	data += '"' + fileLocation + '/' + SVR_JITTER_SORTED + '" using 1:(1.0/pointcount2) smooth cumulative with lines lw 3 linecolor rgb "' + color[1] + '" t "server to client"'
	jitterPlotFile.write(data)
	jitterPlotFile.close()
	subprocess.Popen("gnuplot " + fileLocation + "/" + JITTER_CDF_GRAPH, shell = True)
	
def jitterCDFAnalyze(file):
	outDirectory = PLOT_DIR + "/" + file.split('.pcap')[0]
	files = os.listdir(outDirectory)
	if SVR_JITTER and CLT_JITTER in files:
		jiiterAtServerFloatSorted = sorted(map(float, open(outDirectory + '/' + SVR_JITTER, 'r').read().splitlines()))
		jiiterAtServerSortedFile = open(outDirectory + '/' + SVR_JITTER_SORTED, 'w')
		for jitter in range(0, len(jiiterAtServerFloatSorted)):
			jiiterAtServerSortedFile.write(str(jiiterAtServerFloatSorted[jitter])+'\n')
		
		jiiterAtClientFloatSorted = sorted(map(float, open(outDirectory + '/' + CLT_JITTER, 'r').read().splitlines()))
		jiiterAtClientSortedFile = open(outDirectory + '/' + CLT_JITTER_SORTED, 'w')
		for jitter in range(0, len(jiiterAtClientFloatSorted)):
			jiiterAtClientSortedFile.write(str(jiiterAtClientFloatSorted[jitter])+'\n')
		
		jitterCDFPlotAll(outDirectory)
	else:
		print "\t\tEither of the following file is missing: " + SVR_JITTER + ' or ' + CLT_JITTER
		print "\t\tYou can copy those files to " + outDirectory + " and run this script again."
		sys.exit()

'''
Multiplot - Jitter CDF for multiple cases (Up to 10)
'''
def generateJitterCDFMultiplot(numOfPlots):
	if numOfPlots > 10:
		print "\tThe Multiplot graph supports drawing up to 10\n"
		sys.exit()
	
	entriesTocompare = os.listdir(PLOT_DIR)
	if(len(entriesTocompare) == 0):
		print "\tThere is no generated plot to compare with\n"
	
	print "\t\t* Jitter CDF Multiplot (" + str(numOfPlots) + ")"
	
	# jitterMultiplot for client and server respectively
	#color = ['blue', 'green', 'red', 'black']
	color = ['#330000', '#FF0000', '#009900', '#003366', '#4C0099', '#404040', '#660000', '#000066', '#808080','#0080FF']
	jitterMultiplotFile1 = open('./' + JITTER_CDF_MULTI_GRAPH_CLT , 'w')
	data = '# UDP Jitter CDF Multiplot Graph (client)\n'
	data += 'set style data lines\n' 
	data += 'set title "Jitter CDF Comparison (client)"\n'
	data += 'set key bottom right\n'
	data += 'set xlabel "Jitter (ms)"\n'
	data += 'set ylabel "CDF"\n'
	data += 'set xrange [-150:150]\n'
	data += 'set yrange [0:1]\n'
	data += 'set term postscript color eps enhanced "Helvetica" 16\n'
	data += 'set size ratio 0.5\n'
	data += 'set style line 80 lt 0\n'
	data += 'set grid back linestyle 81\n'
	data += 'set border 3 back linestyle 80\n'
	data += 'set xtics nomirror\n'
	data += 'set ytics nomirror\n'
	data += 'set out "' + './' + JITTER_CDF_MULTI_PLOT_CLT + '"\n'
	data += 'a=0\n'
	data += 'cumulative_sum(x)=(a=a+x,a)\n'
	data += 'countpoints(file) = system( sprintf("grep -v ^# %s| wc -l", file) )\n'
	
	i = 0
	for entry in entriesTocompare:
		data += 'pointcount' + str(i) + ' = countpoints("' + PLOT_DIR + '/' + entry + '/' + CLT_JITTER_SORTED + '")\n'
		i = i + 1
	
	data += 'plot '
	j = 0
	while j < len(entriesTocompare) - 1:
		data += '"' + PLOT_DIR + '/' + entriesTocompare[j] + '/' + CLT_JITTER_SORTED + '" using 1:(1.0/pointcount' + str(j) + ') smooth cumulative with lines lw 3 linecolor rgb "' + color[j % len(color)] + '" t "' + entriesTocompare[j].replace('_','-') + '", '
		j = j + 1
	data += '"' + PLOT_DIR + '/' + entriesTocompare[j] + '/' + CLT_JITTER_SORTED + '" using 1:(1.0/pointcount' + str(j) + ') smooth cumulative with lines lw 3 linecolor rgb "' + color[j % len(color)] + '" t "' + entriesTocompare[j].replace('_','-') + '"\n'
	
	jitterMultiplotFile1.write(data)
	subprocess.Popen("gnuplot ./" + JITTER_CDF_MULTI_GRAPH_CLT, shell = True)
	
	jitterMultiplotFile2 = open('./' + JITTER_CDF_MULTI_GRAPH_SVR , 'w')
	data = '# UDP Jitter CDF Multiplot Graph (server) \n'
	data += 'set style data lines\n' 
	data += 'set title "Jitter CDF Comparison (server)"\n'
	data += 'set key bottom right\n'
	data += 'set xlabel "Jitter (ms)"\n'
	data += 'set ylabel "CDF"\n'
	data += 'set xrange [-150:150]\n'
	data += 'set yrange [0:1]\n'
	data += 'set term postscript color eps enhanced "Helvetica" 16\n'
	data += 'set size ratio 0.5\n'
	data += 'set style line 80 lt 0\n'
	data += 'set grid back linestyle 81\n'
	data += 'set border 3 back linestyle 80\n'
	data += 'set xtics nomirror\n'
	data += 'set ytics nomirror\n'
	data += 'set out "' + './' + JITTER_CDF_MULTI_PLOT_SVR + '"\n'
	data += 'a=0\n'
	data += 'cumulative_sum(x)=(a=a+x,a)\n'
	data += 'countpoints(file) = system( sprintf("grep -v ^# %s| wc -l", file) )\n'
	
	i = 0
	for entry in entriesTocompare:
		data += 'pointcount' + str(i) + ' = countpoints("' + PLOT_DIR + '/' + entry + '/' + SVR_JITTER_SORTED + '")\n'
		i = i + 1
	
	data += 'plot '
	j = 0
	while j < len(entriesTocompare) - 1:
		data += '"' + PLOT_DIR + '/' + entriesTocompare[j] + '/' + SVR_JITTER_SORTED + '" using 1:(1.0/pointcount' + str(j) + ') smooth cumulative with lines lw 3 linecolor rgb "' + color[j % len(color)] + '" t "' + entriesTocompare[j].replace('_','-') + '", '
		j = j + 1
	data += '"' + PLOT_DIR + '/' + entriesTocompare[j] + '/' + SVR_JITTER_SORTED + '" using 1:(1.0/pointcount' + str(j) + ') smooth cumulative with lines lw 3 linecolor rgb "' + color[j % len(color)] + '" t "' + entriesTocompare[j].replace('_','-') + '"\n'
	
	jitterMultiplotFile2.write(data)
	subprocess.Popen("gnuplot ./" + JITTER_CDF_MULTI_GRAPH_SVR, shell = True)

'''
Helper functions to prepare for UDP Jitter CDF analysis

Simple UDP Jitter calculation
Si: the timestamp from packet i, 
Ri: the time of arrival in RTP timestamp units for packet i, 
J: the interarrival between two packets i and j,
J(i,j) = (Rj - Ri) - (Sj - Si) = (Rj - Sj) - (Ri - Si)
Output is in milliseconds
'''

# Extracts two files containing the packets which server sent and which received from client respectively
def splitPcap2(outDir, file_name, client, server):
	split_cs = ("tshark -r \"" + UDP_PCAP_DIR + "/" + file_name + "\" | grep \"" + client + " -> " + server + "\" > " + outDir + "/" + SVR_RCVD)
	os.system(split_cs)
	split_sc = ("tshark -r \"" + UDP_PCAP_DIR + "/" + file_name + "\" | grep \"" + server + " -> " + client + "\" > " + outDir + "/" + SVR_SENT)
	os.system(split_sc)
    
def udpDelay2(outDirectory):
	f1 = open(outDirectory + "/" + CLT_SENT_INTVL, 'r')
	f2 = open(outDirectory + "/" + SVR_RCVD_INTVL, 'r')
	f3 = open(outDirectory + "/" + SVR_SENT_INTVL, 'r')
	f4 = open(outDirectory + "/" + CLT_RCVD_INTVL, 'r')

	interval1 = [line.rstrip() for line in f1]
	interval2 = [line.rstrip() for line in f2]
	interval3 = [line.rstrip() for line in f3]
	interval4 = [line.rstrip() for line in f4]
	
	statFile = open(outDirectory + "/" + STATS_TXT, "w")
	
	num_client_sent = len(interval1) + 1
	num_server_rcvd = len(interval2) + 1
	lossRateCS = 100.0 - (float(num_server_rcvd)/float(num_client_sent))*100
	
	if DEBUG == 2: print "\tProcessing delay at server..."
	if lossRateCS < 0:
		if DEBUG == 2: print "\t\tLoss Rate = %3.2f%% (%d / %d)" % (lossRateCS, num_server_rcvd, num_client_sent) + "<--WHAT?? SOMETHING IS WRONG!"
	else:
		if DEBUG == 2: print "\t\tLoss Rate = %3.2f%% (%d / %d)" % (lossRateCS, num_server_rcvd, num_client_sent)
	if DEBUG == 2: print "\t\tClient has sent " + str(num_client_sent) + " UDP packets and",
	if DEBUG == 2: print "server has received " + str(num_server_rcvd)+ " UDP packets."

	statFile.write("udp_client_sent: " + str(num_client_sent) + "\n")
	statFile.write("udp_server_rcvd: " + str(num_server_rcvd) + "\n")
	statFile.write("udp_loss_rate_client_to_server: " + str(lossRateCS) + " %\n")

	jiiterAtServer = []
	for x in range(0,len(interval1)-1) if len(interval1) <= len(interval2) else range(0,len(interval2)-1):
		jiiterAtServer.append(format_float(1000*(float(interval2[x])-float(interval1[x])),15))
	
	jiiterAtServerFloat = map(float, jiiterAtServer)
	jiiterAtServerFile = open(outDirectory + '/' + SVR_JITTER ,'w')
	for jitter in range(0, len(jiiterAtServerFloat)):
		jiiterAtServerFile.write(str(jiiterAtServerFloat[jitter])+'\n')
	
	f1.close()
	f2.close()

	num_server_sent = len(interval3) + 1
	num_client_rcvd = len(interval4) + 1
	lossRateSC = 100.0 - (float(num_client_rcvd)/float(num_server_sent))*100
	
	if DEBUG == 2: print "\tProcessing delay at client..."
	if lossRateSC < 0:
		if DEBUG == 2: print "\t\tLoss Rate = %3.2f%% (%d / %d)" % (lossRateSC, num_client_rcvd, num_server_sent) + "<--WHAT?? SOMETHING IS WRONG!"
	else:
		if DEBUG == 2: print "\t\tLoss Rate = %3.2f%% (%d / %d)" % (lossRateSC, num_client_rcvd, num_server_sent)
	if DEBUG == 2: print "\t\tServer has sent " + str(num_server_sent) + " UDP packets and",
	if DEBUG == 2: print "client has received " + str(num_client_rcvd)+ " UDP packets."

	statFile.write("udp_server_sent: " + str(num_server_sent) + "\n")
	statFile.write("udp_client_rcvd: " + str(num_client_rcvd) + "\n")
	statFile.write("udp_loss_rate_server_to_client: " + str(lossRateSC) + " %\n")
	
	jiiterAtClient = []
	for x in range(0,len(interval3)-1) if len(interval3) <= len(interval4) else range(0,len(interval4)-1):
		jiiterAtClient.append(format_float(1000*(float(interval4[x])-float(interval3[x])),15))

	jiiterAtClientFloat = map(float, jiiterAtClient)
	jiiterAtClientFile = open(outDirectory + '/' + CLT_JITTER, 'w')
	for jitter in range(0, len(jiiterAtClientFloat)):
		jiiterAtClientFile.write(str(jiiterAtClientFloat[jitter])+'\n')
	
	f3.close()
	f4.close()

def extractEndpoints2(out_dir, file_name):
	extract = ("tshark -Tfields -E separator=- -e ip.src -e ip.dst -r " + UDP_PCAP_DIR + "/" + file_name +" | head -1 > " + out_dir + "/" + ENDPOINTS)
	os.system(extract)
	with open(out_dir + "/" + ENDPOINTS, 'r') as f:
		ends = f.read().splitlines()
	f.close()
	try:
		endpoints = ends[0].split("-")
	except:
		print "Failed to extract two endpoints from " + out_dir + "/" + file_name
	return endpoints

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
def jitterPreProcessing(outDirectory, file_name, replaying_dir):
	# Extracting client/server packets from two endpoints respectively. (IP might be different due to NAT/PAT.)
	if DEBUG == 2: 
		print "\tTarget file: " + file_name
	try:
		endpoints = extractEndpoints2(outDirectory, file_name)
		client = endpoints[0]
		server = endpoints[1]
	except:
		print "\tFailed to extract two endpoints."
		sys.exit(-1)
	if DEBUG == 2: 
		print "\t" + "Client: " + client + " <-> Server: " + server + " from server side"
	splitPcap2(outDirectory, file_name, client, server)
	
	# Count all UDP Packets on server side.
	if DEBUG == 2: 
		print "\t# of UDP packets collected on server side: " + str(pkt_ctr(UDP_PCAP_DIR, file_name, 'udp'))
	
	# Bring the delay from parsed UDP Packets on server side.
	if DEBUG == 2: 
		print "\tThere are " + parsedPktCnt2(outDirectory, SVR_SENT) + " packets which server has successfully sent."
	if DEBUG == 2: 
		print "\tThere are " + parsedPktCnt2(outDirectory, SVR_RCVD) + " packets which server has successfully received."
	
	# Bring inter-packet timestamps UDP Packets on server side.
	getTimestamp2(outDirectory, SVR_SENT)
	interPacketSentInterval2(outDirectory, SVR_SENT)
	if DEBUG == 2: print "\t" + SVR_SENT_INTVL + " has been created!"
	getTimestamp2(outDirectory, SVR_RCVD)
	interPacketSentInterval2(outDirectory, SVR_RCVD)
	if DEBUG == 2: print "\t" + SVR_RCVD_INTVL + " has been created!"

	# Bring the received file from client.
	if replaying_dir is not None:
		os.system("cp " + replaying_dir + "/" + CLT_SENT_INTVL + " " + outDirectory + "/" + CLT_SENT_INTVL)
		os.system("cp " + replaying_dir + "/" + CLT_RCVD_INTVL + " " + outDirectory + "/" + CLT_RCVD_INTVL)
		udpDelay2(outDirectory)
	else:
		if os.path.isfile(outDirectory + "/" + CLT_SENT_INTVL) == True and os.path.isfile(outDirectory + "/" + CLT_RCVD_INTVL) == True:
			udpDelay2(outDirectory)
		else:
			print "\tThe file " + CLT_SENT_INTVL + " and " + CLT_RCVD_INTVL + " are missing."
			print "\tYou may want to manually copy those files to " + outDirectory
			sys.exit(1)
		
# Generate appropriate files to draw jitter CDF graph
def jitterPlotReady(replaying_dir = None):
	# Moving all captured "*_out.pcap" files during replaying process
	pcap_files = []
	if replaying_dir is None:
		i = 0
		for pcap_file in os.listdir(UDP_PCAP_DIR):
			if pcap_file.endswith('.pcap'):
				outDirectory = PLOT_DIR + "/" + pcap_file.split('.pcap')[0]
				if os.path.isdir(outDirectory) == False:
					os.mkdir(outDirectory)
				pcap_files.append(os.path.abspath('.') + '/' + pcap_file)
			try:
				(absolute_path, file_name) = os.path.split(pcap_files[i])
			except:
				print "\tError occured while processing " + absolute_path + "/" + file_name
			jitterPreProcessing(outDirectory, file_name, replaying_dir)
			i = i + 1
	else:
		for pcap_file in os.listdir(REPLAYING_PCAP_DIR):
			if pcap_file.endswith('_out.pcap'):
				outDirectory = PLOT_DIR + "/" + pcap_file.split('.pcap')[0]
				if os.path.isdir(outDirectory) == False:
					os.mkdir(outDirectory)
				pcap_files.append(os.path.abspath('.') + '/' + pcap_file)
				print "\tMoving " + pcap_file + " to " +  UDP_PCAP_DIR
				os.system("mv " + REPLAYING_PCAP_DIR + "/" + pcap_file + " " + UDP_PCAP_DIR + "/" + pcap_file)
		try:
			(absolute_path, file_name) = os.path.split(pcap_files[0])
		except:
			print "\tError occured while processing " + pcap_file
		jitterPreProcessing(outDirectory, file_name, replaying_dir)
		return file_name


'''
Packet size CDF analysis
'''
def pktSizeCDFPlot(fileLocation, type):
	color = ['blue', 'green']
	fileName = fileLocation.split("/")[-1]
	pktSizePlotFile = open(fileLocation + '/' + PKT_CDF_GRAPH, 'w')
	data = '# Sorted packet sizes\n'
	data += 'set title "Packet size CDF (' + fileName.replace('_','-') + ')"\n'
	data += 'set style data lines\n' 
	data += 'set key bottom right\n'
	data += 'set ylabel "CDF" font "Courier, 14"\n'
	data += 'set xlabel "Packet Size (Bytes)" font "Courier, 14"\n'
	data += 'set yrange [0:1]\n'
	data += 'set term postscript color eps enhanced "Helvetica" 16\n'
	data += 'set grid back linestyle 81\n'
	data += 'set xtics nomirror\n'
	data += 'set ytics nomirror\n'
	data += 'set out "' + fileLocation + '/' + PKT_CDF_PLOT + '"\n'
	data += 'a=0\n'
	data += 'cumulative_sum(x)=(a=a+x,a)\n'
	data += 'countpoints(file) = system( sprintf("grep -v ^# %s| wc -l", file) )\n'
	
	if type == UDP_PCAP_DIR:
		data += 'pointcount1 = countpoints("' + fileLocation + '/' + SVR_RCVD_PKT_CDF_TXT + '")\n'
		data += 'pointcount2 = countpoints("' + fileLocation + '/' + SVR_SENT_PKT_CDF_TXT + '")\n'
		data += 'plot "' + fileLocation + '/' + SVR_RCVD_PKT_CDF_TXT + '" using 1:(1.0/pointcount1) smooth cumulative with lines lw 3 linecolor rgb "' + color[0] + '" t "pkts server rcvd", '
		data += '"' + fileLocation + '/' + SVR_SENT_PKT_CDF_TXT + '" using 1:(1.0/pointcount2) smooth cumulative with lines lw 3 linecolor rgb "' + color[1] + '" t "pkts server sent"'
	elif type == TCP_PCAP_DIR:
		data += 'pointcount = countpoints("' + fileLocation + '/' + SVR_PKT_CDF_TXT + '")\n'
		data += 'plot "' + fileLocation + '/' + SVR_PKT_CDF_TXT + '" using 1:(1.0/pointcount) smooth cumulative with lines lw 3 linecolor rgb "' + color[0] + '" t "pkts"'
	else:
		pass
		
	pktSizePlotFile.write(data)
	pktSizePlotFile.close()
	subprocess.Popen("gnuplot " + fileLocation + "/" + PKT_CDF_GRAPH, shell = True)

def pktSizeCDFAnalyze(file, type):
	outDirectory = PLOT_DIR + "/" + file.split('.pcap')[0]
	fileName = outDirectory.split("/")[-1]
	
	if type == UDP_PCAP_DIR:
		server_rcvd_pkt_cmd = "cat " + outDirectory + "/" + SVR_RCVD + " | grep -v 'Frame' | awk '{print $7}' > " + outDirectory + "/tmp_" + SVR_RCVD_PKT_CDF_TXT
		server_sent_pkt_cmd = "cat " + outDirectory + "/" + SVR_SENT + " | grep -v 'Frame' | awk '{print $7}' > " + outDirectory + "/tmp_" + SVR_SENT_PKT_CDF_TXT 
		os.system(server_rcvd_pkt_cmd)
		os.system(server_sent_pkt_cmd)
		
		rcvd_pkt_sizes = sorted(map(int, open(outDirectory + "/tmp_" + SVR_RCVD_PKT_CDF_TXT, "r").read().splitlines()))
		sent_pkt_sizes = sorted(map(int, open(outDirectory + "/tmp_" + SVR_SENT_PKT_CDF_TXT, "r").read().splitlines()))

		if os.path.isfile(outDirectory + "/" + SVR_RCVD_PKT_CDF_TXT) == True:
			os.remove(outDirectory + "/" + SVR_RCVD_PKT_CDF_TXT)
		if os.path.isfile(outDirectory + "/" + SVR_SENT_PKT_CDF_TXT) == True:
			os.remove(outDirectory + "/" + SVR_SENT_PKT_CDF_TXT)

		for rcvd_pkt_size in rcvd_pkt_sizes:
			open(outDirectory + "/" + SVR_RCVD_PKT_CDF_TXT, "a").write(str(rcvd_pkt_size) + "\n") 
		for sent_pkt_size in sent_pkt_sizes:
			open(outDirectory + "/" + SVR_SENT_PKT_CDF_TXT, "a").write(str(sent_pkt_size) + "\n")
		
		os.remove(outDirectory + "/tmp_" + SVR_RCVD_PKT_CDF_TXT)
		os.remove(outDirectory + "/tmp_" + SVR_SENT_PKT_CDF_TXT)
	
	elif type == TCP_PCAP_DIR:
		#server_client_extract_cmd = ("cat " + TXT_PCAP_DIR + "/" + fileName + "_rtt.txt" + " | grep -v tcp | grep 0.00000000 | awk -F',' '{print $3, $5}' | awk -F'\"' '{print $2, $4}'")
		#endpoints = commands.getoutput(server_client_extract_cmd)
		#client = endpoints.split(' ')[0]
		#server = endpoints.split(' ')[1]
		
		server_pkt_cmd = "cat " + TXT_PCAP_DIR + "/" + fileName + "_rtt.txt" + " | awk -F',' '{print $10}' | grep -v tcp > " + outDirectory + "/tmp_" + SVR_PKT_CDF_TXT
		os.system(server_pkt_cmd)
		
		raw_pkt_sizes = open(outDirectory + "/tmp_" + SVR_PKT_CDF_TXT, "r").readlines()
		pkt_sizes = []
		for pkt_size in raw_pkt_sizes:
			if pkt_size == "":
				pkt_size = 0
			else:
				pkt_sizes.append(pkt_size.strip('\n').replace('\"',''))
		if os.path.isfile(outDirectory + "/" + SVR_PKT_CDF_TXT) == True:
			os.remove(outDirectory + "/" + SVR_PKT_CDF_TXT)
		for pkt_size in sorted(map(int, [x for x in pkt_sizes if x !=''])):
			open(outDirectory + "/" + SVR_PKT_CDF_TXT, "a").write(str(pkt_size) + "\n") 
		os.remove(outDirectory + "/tmp_" + SVR_PKT_CDF_TXT)
	
	else:
		pass
		
	pktSizeCDFPlot(outDirectory, type)

'''
Multiplot - Packet Size CDF for multiple cases for TCP(Up to 10)
'''
def generatePktSizeCDFMultiplot(numOfPlots):
	if numOfPlots > 10:
		print "\tThe Multiplot graph supports drawing up to 10\n"
		sys.exit()
	
	entriesTocompare = os.listdir(PLOT_DIR)
	if(len(entriesTocompare) == 0):
		print "\tThere is no generated plot to compare with\n"
	
	print "\t\t* Packet Size CDF Multiplot (" + str(numOfPlots) + ")"
	
	#color = ['blue', 'green', 'red', 'black']
	color = ['#330000', '#FF0000', '#009900', '#003366', '#4C0099', '#404040', '#660000', '#000066', '#808080','#0080FF']
	pktSizeMultiplotFile = open('./' + PKT_SIZE_CDF_MULTI_GRAPH, 'w')
	data = '# Packet Size CDF Multiplot Graph \n'
	data += 'set style data lines\n' 
	data += 'set title "Packet Size CDF Comparison"\n'
	data += 'set key bottom right\n'
	data += 'set xlabel "Packet Size (Bytes)"\n'
	data += 'set ylabel "CDF"\n'
	data += 'set yrange [0:1]\n'
	data += 'set term postscript color eps enhanced "Helvetica" 16\n'
	data += 'set size ratio 0.5\n'
	data += 'set style line 80 lt 0\n'
	data += 'set grid back linestyle 81\n'
	data += 'set border 3 back linestyle 80\n'
	data += 'set xtics nomirror\n'
	data += 'set ytics nomirror\n'
	data += 'set out "' + './' + PKT_SIZE_CDF_MULTI_PLOT + '"\n'
	data += 'a=0\n'
	data += 'cumulative_sum(x)=(a=a+x,a)\n'
	data += 'countpoints(file) = system( sprintf("grep -v ^# %s| wc -l", file) )\n'
	
	i = 0
	for entry in entriesTocompare:
		data += 'pointcount' + str(i) + ' = countpoints("' + PLOT_DIR + '/' + entry + '/' + RTT_CDF_TXT + '")\n'
		i = i + 1
	
	data += 'plot '
	j = 0
	while j < len(entriesTocompare) - 1:
		data += '"' + PLOT_DIR + '/' + entriesTocompare[j] + '/' + SVR_PKT_CDF_TXT + '" using 1:(1.0/pointcount' + str(j) + ') smooth cumulative with lines lw 3 linecolor rgb "' + color[j % len(color)] + '" t "' + entriesTocompare[j].replace('_','-') + '", '
		j = j + 1
	data += '"' + PLOT_DIR + '/' + entriesTocompare[j] + '/' + SVR_PKT_CDF_TXT + '" using 1:(1.0/pointcount' + str(j) + ') smooth cumulative with lines lw 3 linecolor rgb "' + color[j % len(color)] + '" t "' + entriesTocompare[j].replace('_','-') + '"\n'
	
	pktSizeMultiplotFile.write(data)
	pktSizeMultiplotFile.close()
	subprocess.Popen("gnuplot ./" + PKT_SIZE_CDF_MULTI_GRAPH, shell = True)

'''
The K-S Test using R here is as following:
1. Remove outliers
2. Extract the half number of samples from comparing target  
3. Compare two distributions (one for baseline, the other one for comparison)
4. If p-value is larger than 0.05, then we can accept the null hypothesis. 
	In this case, we can say two dists derive from the same one.
	If not (p < 0.05), we should reject H0 or two dists are significantly different.
5. The R generates cdf and boxplot in a single ps file.
'''
def ksTest(origin, compared, labelX):
	rFileForEachExp = R_FILE.split('.')[0] + "_" + origin.split('/')[-2] + "-" + compared.split('/')[-2] + "-" + labelX.split(' ')[0] + "." + R_FILE.split('.')[1] 
	ksResultForEachExp = KS_RESULT_TXT.split('.')[0] + "_" + origin.split('/')[-2] + "-" + compared.split('/')[-2] + "-" + labelX.split(' ')[0] + "." + KS_RESULT_TXT.split('.')[1]
	ksResultPsForEachExp = KS_RESULT_PS.split('.')[0] + "_" + origin.split('/')[-2] + "-" + compared.split('/')[-2] + "-" + labelX.split(' ')[0] + "." + KS_RESULT_PS.split('.')[1]
	rFile = open('./' + rFileForEachExp, 'w')
	data = '# K-S(Kolmogorov-Smirnov) Test using R\n'
	data += 'remove_outliers <- function(x, na.rm = TRUE, ...) {\n'
	data += '  qnt <- quantile(x, probs=c(.01, .99), na.rm = na.rm, ...)\n'
	data += '  H <- 1.5 * IQR(x, na.rm = na.rm)\n'
	data += '  y <- x\n'
	data += '  y[x < (qnt[1] - H)] <- NA\n'
	data += '  y[x > (qnt[2] + H)] <- NA\n'
	data += '  y\n'
	data += '}\n'
	data += '\n'
	data += 'origin <- read.table("' + origin +'")\n'
	data += 'originValues <- origin$V1\n'
	data += 'comparison <- read.table("' + compared + '")\n'
	data += 'comparisonValues <- comparison$V1\n'
	data += '\n'
	data += '#originValuesWithoutOutliers <- remove_outliers(originValues)\n'
	data += 'originValuesWithoutOutliers <- originValues[!originValues %in% boxplot.stats(originValues)$out]\n'
	data += '#comparisonValuesWithoutOutliers <- remove_outliers(comparisonValues)\n'
	data += 'comparisonValuesWithoutOutliers <- comparisonValues[!comparisonValues %in% boxplot.stats(comparisonValues)$out]\n'
	data += 'comparisonSamples <- sample(comparisonValuesWithoutOutliers, round(length(comparisonValuesWithoutOutliers)/2), prob = NULL)\n'
	data += '\n'
	data += 'saveResult <- file("' + ksResultForEachExp + '", open="wt")\n'
	data += 'sink(saveResult)\n'
	data += '#message("[A] Summary of originValues (samples:", length(originValues), ")")\n'
	data += '#summary(originValues)\n'
	data += '#writeLines("")\n'
	data += '#message("[B] Summary of originValuesWithoutOutliers (samples:", length(originValuesWithoutOutliers), ")")\n'
	data += '#summary(originValuesWithoutOutliers)\n'
	data += '#writeLines("")\n'
	data += '#message("[C] Summary of comparisonValues (samples:", length(comparisonValues), ")")\n'
	data += '#summary(comparisonValues)\n'
	data += '#writeLines("")\n'
	data += '#message("[D] Summary of comparisonValuesWithoutOutliers (samples:", length(comparisonValuesWithoutOutliers), ")")\n'
	data += '#summary(comparisonValuesWithoutOutliers)\n'
	data += '#writeLines("")\n'
	data += '#message("[E] Summary of comparisonSamples (samples:", length(comparisonSamples), ")")\n'
	data += '#summary(comparisonSamples)\n'
	data += '#writeLines("")\n'
	data += '\n'
	data += 'ks.test(originValuesWithoutOutliers, comparisonSamples)\n'
	data += '\n'
	data += 'postscript("' + ksResultPsForEachExp + '")\n'
	data += 'par(mfrow=c(1,2))\n'
	data += 'plot(ecdf(originValuesWithoutOutliers), do.points=FALSE, verticals=TRUE, xlim=range(originValuesWithoutOutliers, comparisonSamples), main="CDF of Sample Distributions", xlab="' + labelX + '", ylab="CDF", panel.first = grid())\n'
	data += 'plot(ecdf(comparisonSamples), do.points=FALSE, verticals=TRUE, add=TRUE, col="red")\n'
	# line type arguments: ("solid", "dashed", "dotted", "dotdash")
	data += 'legend("bottomright", legend = c("' + origin.split('/')[-2] + '", "' + compared.split('/')[-2] + '"), col=c("black", "red"), lty=c("solid", "solid"))\n'
	data += 'boxplot(list(' + origin.split('/')[-2] + '=originValuesWithoutOutliers, ' + compared.split('/')[-2] + '=comparisonSamples))\n'
	data += '#dev.off()\n'
	
	rFile.write(data)
	rFile.close()
	
	#subprocess.Popen(R_COMMAND + " ./" + rFileForEachExp + "2> /dev/null", shell = True)
	try:
		print "Generating R script for future use.."
		os.system('R_COMMAND + " ./" + rFileForEachExp + " 2> /dev/null"')
	except:
		print "Failed to use R.."
		exit(1)
	#return commands.getoutput("cat ./" + ksResultForEachExp + " | grep p-value")
	#print "All result file from R has been saved to " + ksResultForEachExp + " and " + KS_RESULT_PS + "..."
	
def ksTestFinalDecision(description, origin, compared):
	base = importr('base')
	stats = importr('stats')
	graphics = importr('graphics')
	grdevices = importr('grDevices')
	
	# Get K-S test via execute string as R statement
	kstest = robjects.r('ks.test')
	# Get a built-in function variables directly
	pexp = robjects.r.pexp

	# Defined functions in R and call them in python through rpy interface
	robjects.r(r'''
		getOriginValuesWithoutOutliers <- function(x) {
			origin <- read.table(x)
			originValues <- origin$V1
			originValuesWithoutOutliers <- originValues[!originValues %in% boxplot.stats(originValues)$out]
		}
		getComparisonSamples <- function(y) {
			comparison <- read.table(y)
			comparisonValues <- comparison$V1
			comparisonValuesWithoutOutliers <- comparisonValues[!comparisonValues %in% boxplot.stats(comparisonValues)$out]
			comparisonSamples <- sample(comparisonValuesWithoutOutliers, round(length(comparisonValuesWithoutOutliers)/2), prob = NULL)
		}''')

	pValueSum = 0.0
	dStatisticSum = 0.0
	numOfTest = 100

	for i in range(0, numOfTest):
		getOriginValuesF = robjects.r['getOriginValuesWithoutOutliers']
		getComparisonValuesF = robjects.r['getComparisonSamples']
		originValues = getOriginValuesF(origin)
		comparisonValues = getComparisonValuesF(compared)
		
		result = kstest(originValues, comparisonValues, pexp)
		pValueSum = pValueSum + float(result[result.names.index('p.value')][0])
		dStatisticSum = dStatisticSum + float(result[result.names.index('statistic')][0])

	pAvg = float(pValueSum/numOfTest)
	dAvg = float(dStatisticSum/numOfTest)
	# print "P-Value: " + str(result[result.names.index('p.value')][0])		# P-value
	# print "D-Value: " + str(result[result.names.index('statistic')][0])		# D-value (statistic)

	# Describes the summary for the last ks-test
	summary1 = robjects.r.summary(originValues)
	summary2 = robjects.r.summary(comparisonValues)
	print "\tBaseline summary: "	#(Population=" + str(len(originValues)) + ")"
	print "\t\tMin: " + str(summary1[0]) + ", Median: " + str(summary1[2]) + ", Mean: " + str(summary1[3]) + ", Max: " + str(summary1[5])
	print "\tTarget summary: "		#(Samples=" + str(len(comparisonValues)) + ")"
	print "\t\tMin: " + str(summary2[0]) + ", Median: " + str(summary2[2]) + ", Mean: " + str(summary2[3]) + ", Max: " + str(summary2[5])
	print "\tTwo-sample Kolmogorov-Smirnov test: (# of Tests=" + str(numOfTest) + ")"
	print "\t\tAverage P-value: " + str(pAvg) + ", Average statistic (D): " + str(dAvg)

	# Draw plots (ecdf / boxplot) for the last ks-test
	psPlot = KS_RESULT_PS.split('.')[0] + "_" + origin.split('/')[-2] + "-VS-" + compared.split('/')[-2] + "-" + description.split(' ')[0] + "." + KS_RESULT_PS.split('.')[1]
	grdevices.postscript(file=psPlot, width=512, height=512)
	graphics.par(mfrow = array.array('i', [1,2]))
	legendArgs = 'bottomright, legend = c(' + origin.split('/')[-2] + ', ' + compared.split('/')[-2] + '), col=c(black, red), lty=c(solid, solid)'
	title = "CDF of Sample Distributions (" + origin.split('/')[-2] + " VS " + compared.split('/')[-2] + ")"
	plotargs1 = {'do.points':"FALSE", 'verticals':"TRUE", 'main':title, 'xlab':description, 'ylab':"CDF", 'legend':legendArgs}
	graphics.plot(robjects.r.ecdf(originValues), **plotargs1)
	plotargs2 = {'do.points':"FALSE", 'verticals':"TRUE", 'add':"TRUE", 'col':"red"}
	graphics.plot(robjects.r.ecdf(comparisonValues), **plotargs2)
	#x = origin.split('/')[-2]
	#y = compared.split('/')[-2]
	graphics.boxplot(robjects.r.list(baseline=originValues, target=comparisonValues))
	grdevices.dev_off()
	
	# Final decision with heuristics
	if pAvg >= 0.05 or dAvg <= 0.1:
		print "\t\tH0: accepted, Two Distributions are statistically SAME. "
	else:
		print "\t\tH0: rejected, Two Distributions are statistically DIFFERENT." 
		
def statMedian(list):
	if not list or len(list) == 0:
		return 0
	sortedList = sorted(list)
	length = len(sortedList)
	if length % 2 == 1:
		return float(sortedList[(length + 1) / 2 - 1])
	else:
		return float(sortedList[length / 2 - 1])
	
# Generate "stat.txt" file containing tcp_loss_rate, rtt/xput min/median/avg/max
def tcpStats(file):
	fileName = os.path.splitext(file)[0]
	statFile = open(PLOT_DIR + "/" + fileName + "/" + STATS_TXT, "w")
	tcp_total = commands.getoutput("cat " + TXT_PCAP_DIR + "/" + fileName + "_rtt.txt | wc -l")
	statFile.write("tcp_total: " + str(int(tcp_total) - 1) + "\n")
	tcp_loss = commands.getoutput("tshark -2 -R tcp.analysis.lost_segment -r " + TCP_PCAP_DIR + "/" + file + " | wc -l")
	statFile.write("tcp_loss: " + str(int(tcp_loss)) + "\n")
	statFile.write("tcp_loss_rate: " + str(round(float(tcp_loss)/float(tcp_total)*100, 5)) + " %\n")
	
	rttTxt = PLOT_DIR + "/" + fileName + "/" + RTT_CDF_TXT
	rttMin = commands.getoutput("head -1 " + rttTxt)
	rttMax = commands.getoutput("tail -1 " + rttTxt)
	rttAll = open(rttTxt).read().splitlines()
	rttSum = 0.0
	
	rttMedian = round(float(statMedian(rttAll)),5)
	for rtt in rttAll:
		rttSum += float(rtt)
	rttAvg = round(float(rttSum / len(rttAll)),5)
	
	statFile.write("rtt_min: " + str(float(rttMin)) + " (ms)\n")
	statFile.write("rtt_avg: " + str(rttAvg) + " (ms)\n")
	statFile.write("rtt_median: " + str(rttMedian) + " (ms)\n")
	statFile.write("rtt_max: " + str(float(rttMax)) + " (ms)\n")
	
	xputTxt = PLOT_DIR + "/" + fileName + "/" + XPUT_CDF_TXT
	xputMin = commands.getoutput("head -1 " + xputTxt)
	xputMax = commands.getoutput("tail -1 " + xputTxt)
	xputAll = open(xputTxt).read().splitlines()
	#xputMedian = round(float(statMedian(xputAll), 5)
	
	xputSum = 0.0
	for xput in xputAll:
		xputSum += float(xput)
	xputAvg = round(float(xputSum / len(xputAll)), 5)

	pktSizeSvrTxt = PLOT_DIR + "/" + fileName + "/" + SVR_PKT_CDF_TXT
	pktSizeMin = commands.getoutput("head -1 " + pktSizeSvrTxt)
	pktSizeMax = commands.getoutput("tail -1 " + pktSizeSvrTxt)
	pktSizeSvrAll = open(pktSizeSvrTxt).read().splitlines()
	pktSizeSvrSum = 0.0
	for pktSize in pktSizeSvrAll:
		pktSizeSvrSum += float(pktSize)
	pktSizeSvrAvg = round(float(pktSizeSvrSum / len(pktSizeSvrAll)), 5)
	
	statFile.write("xput_min: " + str(round(float(xputMin), 5)) + " (KB/s)\n")
	statFile.write("xput_avg: " + str(xputAvg) + " (KB/s)\n")
	#statFile.write("xput_median: " + str(xputMedian) + " (KB/s)\n")
	statFile.write("xput_max: " + str(round(float(xputMax), 5)) + " (KB/s)\n")
	statFile.write("pkt_size_avg: " + str(pktSizeSvrAvg) + " [Range: " + pktSizeMin + " - " + pktSizeMax + "] (Bytes)\n")
	statFile.close()
	
# Generate "stat.txt" file containing udp_loss_rate, xput min/avg/max
def udpStats(file):
	fileName = os.path.splitext(file)[0]
	statFile = open(PLOT_DIR + "/" + fileName + "/" + STATS_TXT, "a")
	
	xputTxt = PLOT_DIR + "/" + fileName + "/" + XPUT_CDF_TXT
	xputMin = commands.getoutput("head -1 " + xputTxt)
	xputMax = commands.getoutput("tail -1 " + xputTxt)
	xputAll = open(xputTxt).read().splitlines()
	#xputMedian = round(float(statMedian(xputAll)), 5)
	xputSum = 0.0
	for xput in xputAll:
		xputSum += float(xput)
	xputAvg = round(float(xputSum / len(xputAll)), 5)
	
	pktSizeSvrRcvdTxt = PLOT_DIR + "/" + fileName + "/" + SVR_RCVD_PKT_CDF_TXT
	pktSizeSvrSentTxt = PLOT_DIR + "/" + fileName + "/" + SVR_SENT_PKT_CDF_TXT
	pktSizeRcvdMin = commands.getoutput("head -1 " + pktSizeSvrRcvdTxt)
	pktSizeRcvdMax = commands.getoutput("tail -1 " + pktSizeSvrRcvdTxt)
	pktSizeSentMin = commands.getoutput("head -1 " + pktSizeSvrSentTxt)
	pktSizeSentMax = commands.getoutput("tail -1 " + pktSizeSvrSentTxt)
	pktSizeSvrRcvdAll = open(pktSizeSvrRcvdTxt).read().splitlines()
	pktSizeSvrSentAll = open(pktSizeSvrSentTxt).read().splitlines()
	pktSizeSvrRcvdSum = 0.0
	for pktSize in pktSizeSvrRcvdAll:
		pktSizeSvrRcvdSum += float(pktSize)
	pktSizeSvrRcvdAvg = round(float(pktSizeSvrRcvdSum / len(pktSizeSvrRcvdAll)), 5)
	pktSizeSvrSentSum = 0.0
	for pktSize in pktSizeSvrSentAll:
		pktSizeSvrSentSum += float(pktSize)
	pktSizeSvrSentAvg = round(float(pktSizeSvrSentSum / len(pktSizeSvrSentAll)), 5)
	
	statFile.write("xput_min: " + str(round(float(xputMin), 5)) + " (KB/s)\n")
	statFile.write("xput_avg: " + str(xputAvg) + " (KB/s)\n")
	#statFile.write("xput_median: " + str(xputMedian) + " (KB/s)\n")
	statFile.write("xput_max: " + str(round(float(xputMax), 5)) + " (KB/s)\n")
	statFile.write("pkt_size_avg (sever_rcvd): " + str(pktSizeSvrRcvdAvg) + " [Range: " + pktSizeRcvdMin + " - " + pktSizeRcvdMax + "] (Bytes)\n")
	statFile.write("pkt_size_avg (sever_sent): " + str(pktSizeSvrSentAvg) + " [Range: " + pktSizeSentMin + " - " + pktSizeSentMax + "] (Bytes)\n")
	statFile.close()

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
				pktSizeCDFAnalyze(file, TCP_PCAP_DIR)
				tcpStats(file)
				print '...Done!!'
	print '\tAll generated plots/stats have been saved to ' + PLOT_DIR

def runUDP(replaying_dir):
	# If replaying directory has not been set, then process all UDP pcaps
	if replaying_dir is None:
		jitterPlotReady(replaying_dir)
		files = os.listdir(UDP_PCAP_DIR)
		for file in files:
			if '.' in file and file.split('.')[-1] == "pcap":
				print '\tProcessing "' + file + '"'
				print '\t\tThroughtput ...',
				xPutAnalyze(file, UDP_PCAP_DIR)
				print '...Done!!'
				print '\t\tThroughtput CDF ...',
				xPutCDFAnalyze(file)
				print '\t\t...Done!!'
				print '\t\tJitter CDF ...',
				jitterCDFAnalyze(file)
				pktSizeCDFAnalyze(file, UDP_PCAP_DIR)
				udpStats(file)
				print '...Done!!'

	# If replaying directory has been configured, then process a given UDP pcap
	else:
		file = jitterPlotReady(replaying_dir)
		if '.' in file and file.split('.')[-1] == "pcap":
			print '\tProcessing "' + file + '"'
			print '\t\tThroughtput ...',
			xPutAnalyze(file, UDP_PCAP_DIR)
			print '...Done!!'
			print '\t\tThroughtput CDF ...',
			xPutCDFAnalyze(file)
			print '\t\t...Done!!'
			print '\t\tJitter CDF ...',
			jitterCDFAnalyze(file)
			pktSizeCDFAnalyze(file, UDP_PCAP_DIR)
			udpStats(file)
			print '...Done!!'
	print '\tAll generated plots/stats have been saved to ' + PLOT_DIR

# Check if pcap files are in the pcap directory
def isPcap(pcap_dir):
	files = os.listdir(pcap_dir)
	numOfFiles = 0
	for file in files:
		if '.' in file:
			if file.split('.')[-1] == "pcap":
				numOfFiles += 1
	return numOfFiles

# Check if PLOT_DIR/TCP_PCAP_DIR/UDP_PCAP_DIR and pcaps exist
def chkEnv(protocol):
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
		
	numOfFiles = 0
	if protocol == 'tcp':
		numOfFiles = isPcap(TCP_PCAP_DIR) 
		if numOfFiles == 0:
			print "\tThere is no pcap file extension in the directory: " + TCP_PCAP_DIR
		else:
			print "\t" + str(numOfFiles) + " file(s) have been found in " + TCP_PCAP_DIR
	elif protocol == 'udp':
		numOfFiles = isPcap(UDP_PCAP_DIR)
		if numOfFiles == 0:
			print "\tThere is no pcap file extension in the directory: " + UDP_PCAP_DIR
		else:
			print "\t" + str(numOfFiles) + " file(s) have been found in " + UDP_PCAP_DIR
	else:
		print '\tUnexpected Error! Terminated...'
	
def analysisMain():
	PRINT_ACTION('Reading configs file and args...', 0)
	configs = Configs()
	#configs.set('abbas', False)
	configs.set('multiplot', False)
	configs.set('replaying_dir', None)
	configs.set('proto', None)
	configs.set('kstest', None)
	configs.read_args(sys.argv)
	configs.show_all()
	replaying_dir = configs.get('replaying_dir')
	multiplot = configs.get('multiplot')
	protocol = configs.get('proto')
	kstest = configs.get('kstest')
	
	PRINT_ACTION('Analyzing and drawing plots...', 0)
	'''
	THE PART TO SUPPORT ABBAS CODE HAS BEEN REMOVED!
	if configs.get('abbas') == True:
		print '\tRunning the analysis from Abbas code..'
		copy_pcaps = 'cp ' + TCP_PCAP_DIR + '/*.pcap' + ' ../data/pcaps/'
		os.system(copy_pcaps)
		os.system("bash " + ABBAS_RUN)
		remove_pcaps = 'rm ../data/pcaps/*.pcap' 
		os.system(remove_pcaps)
		print '\tAll generated files have been saved to ' + ABBAS_DIR
	'''
	numOfPlots = 0
	if protocol == 'tcp':
		print '\t[TCP Pcap File Analysis]'
		print '\tMake sure your TCP pcap file is in ' + TCP_PCAP_DIR
		chkEnv(protocol)
		runTCP()
		if multiplot == True:
			print "\tGenerating multiple TCP plots for the purpose of comparison...\n"
			numOfPlots = isPcap(TCP_PCAP_DIR)
			#generateXputCDFMultiplot(numOfPlots)
			generateRTTCDFMultiplot(numOfPlots)
			generatePktSizeCDFMultiplot(numOfPlots)
			print "\tDone..! (Multiplots have been saved to the current directory)\n"
		if kstest == True:
			comparisonDirs = os.listdir(PLOT_DIR)
			if len(comparisonDirs) == 0:
				print "Nothing to compare each other!"
				exit(1)
			print "\n---->    K-S Testing (TCP)   <----"
			print "Note that this testing might not work if " + PLOT_DIR + " is mixed up with TCP/UDP"
			for i in range(0, len(comparisonDirs)):
				print "[" + str(i+1) + "] " + comparisonDirs[i]
			baseline = raw_input("Select the baseline distribution to make a comparison: ")
			for i in range(0, len(comparisonDirs)):
				if comparisonDirs[i] <> comparisonDirs[int(baseline) - 1]:
					print "\t< " + comparisonDirs[int(baseline) - 1] + " VS " + comparisonDirs[i] + " >"
					print "\tThroughtput (KB/s):"
					ksTestFinalDecision("Xput (KB/s)", PLOT_DIR + "/" + comparisonDirs[int(baseline) - 1] + "/" + XPUT_CDF_TXT, PLOT_DIR + "/" + comparisonDirs[i] + "/" + XPUT_CDF_TXT)
					print "\tRTT (ms):"
					ksTestFinalDecision("RTT (ms)", PLOT_DIR + "/" + comparisonDirs[int(baseline) - 1] + "/" + RTT_CDF_TXT, PLOT_DIR + "/" + comparisonDirs[i] + "/" + RTT_CDF_TXT)
				print ""
	elif protocol == 'udp':
		print '\t[UDP Pcap File Analysis]'
		chkEnv(protocol)
		runUDP(replaying_dir)
		if multiplot == True:
			print "\tGenerating multiple UDP plots for the purpose of comparison...\n"
			numOfPlots = isPcap(UDP_PCAP_DIR)
			generateXputCDFMultiplot(numOfPlots)
			generateJitterCDFMultiplot(numOfPlots)
			print "\tDone..! (Multiplots have been saved to the current directory)\n"
		if kstest == True:
			comparisonDirs = os.listdir(PLOT_DIR)
			if len(comparisonDirs) == 0:
				print "Nothing to compare each other!"
				exit(1)
			print "\n---->    K-S Testing (UDP)   <----"
			print "Note that this testing might not work if " + PLOT_DIR + " is mixed up with TCP/UDP"
			for i in range(0, len(comparisonDirs)):
				print "[" + str(i+1) + "] " + comparisonDirs[i]
			baseline = raw_input("Select the baseline distribution to make a comparison: ")
			for i in range(0, len(comparisonDirs)):
				if comparisonDirs[i] <> comparisonDirs[int(baseline) - 1]:
					print "\t< " + comparisonDirs[int(baseline) - 1] + " VS " + comparisonDirs[i] + " >"
					print "\tThroughtput (KB/s):"
					ksTestFinalDecision("Xput (KB/s)", PLOT_DIR + "/" + comparisonDirs[int(baseline) - 1] + "/" + XPUT_CDF_TXT, PLOT_DIR + "/" + comparisonDirs[i] + "/" + XPUT_CDF_TXT)
					print "\tJitter@Server (ms):"
					ksTestFinalDecision("Jitter@Server (ms)", PLOT_DIR + "/" + comparisonDirs[int(baseline) - 1] + "/" + SVR_JITTER_SORTED, PLOT_DIR + "/" + comparisonDirs[i] + "/" + SVR_JITTER_SORTED)
					print "\tJitter@Client (ms):"
					ksTestFinalDecision("Jitter@Client (ms)", PLOT_DIR + "/" + comparisonDirs[int(baseline) - 1] + "/" + CLT_JITTER_SORTED, PLOT_DIR + "/" + comparisonDirs[i] + "/" + CLT_JITTER_SORTED)
				print ""
	else:
		print '\tOops! Provided protocol is NOT supported, Terminated...'
		sys.exit()
	
if __name__ == '__main__':
	if len(sys.argv) < 2:
		print "Usage: " + sys.argv[0] + " --proto=[tcp|udp] --multiplot=[True|False] --replaying_dir=[]"
		print "\tThis program assumes that there exists *.pcap files in the following:" 
		print "\tTCP: " + TCP_PCAP_DIR + ", UDP: " + UDP_PCAP_DIR
		# print "\tIf you use Abbas code, the pcap files will be copied into ../data/pcaps."
		print "\tIf you want to analyze new UDP packets during replaying, the directory should be indicated. (UDP Only)"
		sys.exit()
	analysisMain()