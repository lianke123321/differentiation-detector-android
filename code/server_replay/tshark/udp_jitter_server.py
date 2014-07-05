'''
#######################################################################################################
#######################################################################################################

by: Hyungjoon Koo (hykoo@cs.stonybrook.edu)
    Stony Brook University

Goal: calculate udp jitter between client and server
Required package
	(*) dpkt (https://code.google.com/p/dpkt/)
	(-) numpy (https://pypi.python.org/pypi/numpy)
	(-) gnuplot (http://sourceforge.net/projects/gnuplot-py/files/Gnuplot-py/)

Usage:
    python udp_jitter_server.py --pcap_folder=[]
	
Example:
    python udp_jitter_server.py --pcap_folder=./udp

#######################################################################################################
#######################################################################################################
'''
import sys
import time
from python_lib import *
import dpkt
import socket
import commands
import subprocess
# from numpy import *
# import Gnuplot

DEBUG = 2
# HOST = ''
HOST = '127.0.0.1'
PORT = 12345

# Extracts two files containing the packets which server sent and which received from client respectively
def splitPcap(pcap_dir, file_name, client, server, description):
	split_cs = ("tshark -r \"" + pcap_dir + "/" + file_name + "\" | grep \"" + client + " -> " + server + "\" > " + pcap_dir + "/" + client + "_" + server + "_" + description + "_rcvd.txt")
	os.system(split_cs)
	split_sc = ("tshark -r \"" + pcap_dir + "/" + file_name + "\" | grep \"" + server + " -> " + client + "\" > " + pcap_dir + "/" + server + "_" + client + "_" + description + "_sent.txt")
	os.system(split_sc)
	
'''
# Determines both endpoints
def extractEndpoints(pcap_dir, file_name):
	extract = ("tshark -Tfields -E separator=- -e ip.src -e ip.dst -r " + pcap_dir + "/" + file_name +" | head -1 > " + pcap_dir + "/" + file_name + "_endpoints.txt")
	if DEBUG == 2: print "\t" + extract
	os.system(extract)
	with open(pcap_dir + "/" + file_name + "_endpoints.txt",'r') as f:
		ends = f.read().splitlines()
	f.close()
	return ends[0].split("-")

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

	if DEBUG == 2: print "\ttotal # of packets: %s"  % (total_ctr) 
	if DEBUG == 2: print "\t# of UDP packets: %s" % (udp_ctr)
	if DEBUG == 2: print "\t# of TCP packets: %s" % (tcp_ctr)
	if DEBUG == 2: print "\t# of other packets except for TCP or UDP: %s"  % (other_ctr)
	
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

def parsedPktCnt(pcap_dir, server):
	pktCntCmd = ("cat " + pcap_dir + "/" + server + " " + " | wc -l")
	if DEBUG == 2: print "\t" + pktCntCmd
	pktCnt = commands.getoutput(pktCntCmd)
	return pktCnt

def getTimestamp(pcap_dir, server):
	getTimestampCmd = ("cat " + pcap_dir + "/" + server + " | awk '{print $2}' > " + pcap_dir + "/" + "ts_" + server + ".tmp")
	if DEBUG == 2: print "\t" + getTimestampCmd
	os.system(getTimestampCmd)

def interPacketSentInterval(pcap_dir, server):
	tmp = open(pcap_dir + '/ts_' + server + '.tmp','r')
	timestamps = tmp.read().splitlines()
	
	intervals = []
	i = 0
	ts_cnt = len(timestamps)
	while (i < ts_cnt - 1):
		intervals.append(float(timestamps[i+1]) - float(timestamps[i]))
		i = i + 1
	
	f = open(pcap_dir + '/' + server + '_interPacketIntervals.txt', 'w')
	f.write('\n'.join(str(ts) for ts in intervals))
	
	os.system('rm -f ' + pcap_dir + '/ts_' + server + '.tmp')
'''

# UDP Jitter calculation
# Si: the timestamp from packet i, 
# Ri: the time of arrival in RTP timestamp units for packet i, 
# J: the interarrival between two packets i and j,
# J(i,j) = (Rj - Ri) - (Sj - Si) = (Rj - Sj) - (Ri - Si)
# Output is in milliseconds: {pcap_dir}/[server|client]_delay.txt
def udpDelay(pcap_dir, client_sent_interval, client_rcvd_interval, server_sent_interval, server_rcvd_interval):
    f1 = open(client_sent_interval, 'r')
    f2 = open(server_rcvd_interval, 'r')
    f3 = open(server_sent_interval, 'r')
    f4 = open(client_rcvd_interval, 'r')

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

    delayAtServer = []
    for x in range(0,len(interval1)-1) if len(interval1) <= len(interval2) else range(0,len(interval2)-1):
		delayAtServer.append(format_float(abs(1000*(float(interval2[x])-float(interval1[x]))),15))
	
    f_delayAtServer = open(pcap_dir + '/server_delay.txt','w')
    for delay in range(0, len(delayAtServer)):
        f_delayAtServer.write(delayAtServer[delay]+'\n')
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

    delayAtClient = []
    f_delayAtClient = open(pcap_dir + '/client_delay.txt','w')
    for x in range(0,len(interval3)-1) if len(interval3) <= len(interval4) else range(0,len(interval4)-1):
		delayAtClient.append(format_float(abs(1000*(float(interval4[x])-float(interval3[x]))),15))

    for delay in range(0, len(delayAtClient)):
        f_delayAtClient.write(delayAtClient[delay]+'\n')
    f3.close()
    f4.close()
	
# Receives the jitter result from the client
def receivingFile(file_received):
	s = None

	try:
		s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
	except socket.error as err_msg:
		s = None
	try:
		s.bind((HOST, PORT))
		s.listen(1)
	except socket.error as err_msg:
		s.close()
		s = None

	if s is None:
		print '\tThe socket has a problem. Check it out!'
		print '\tFYI, This program only supports IPv4.'
		sys.exit(1)

	conn, addr = s.accept()
	print '\tConnected by', addr

	f = open(file_received, 'w')

	while 1:
		data = conn.recv(1024)
		if not data: break
		f.write(data)
	
	s.close()
	conn.close()

# Writes the plot file (*.gp) for gnuplot
def writePlotSet(result_dir, endpoint):
	fplot = open(result_dir + '/' + endpoint + '_jitter.gp','w')
	data = '# Sorted jitter on ' + endpoint + ' side\n'
	data += 'set title "UDP Jitter"\n'
	data += 'set style data lines\n' 
	data += 'set key bottom right\n'
	data += 'set ylabel "Jitter CDF" font "Courier, 14"\n'
	data += 'set xlabel "Time (msec)" font "Courier, 14"\n'
	data += 'set yrange [0:1]\n'
	data += 'set term postscript color eps enhanced "Helvetica" 16\n'
	#data += 'set style line 80 lt 0\n'
	data += 'set grid back linestyle 81\n'
	#data += 'set border 3 back linestyle 80\n'
	data += 'set style line 1 lw 4 lc rgb "#990042"\n'
	data += 'set xtics nomirror\n'
	data += 'set ytics nomirror\n'
	data += 'set out "' + result_dir + '/cdf_udpjitter_' + endpoint + '.ps"\n'
	data += 'a=0\n'
	data += 'cumulative_sum(x)=(a=a+x,a)\n'
	data += 'countpoints(file) = system( sprintf("grep -v ^# %s| wc -l", file) )\n'
	data += 'pointcount = countpoints("' + result_dir + '/' + endpoint + '_delay_sorted.txt")\n'
	data += 'plot "' + result_dir + '/' + endpoint + '_delay_sorted.txt" using 1:(1.0/pointcount) smooth cumulative with lines ls 1\n'
	fplot.write(data)

# Draws the plot for UDP jitter
def drawPlot(result_dir, endpoint):
	subprocess.Popen("gnuplot " + result_dir + "/" + endpoint + "_jitter.gp", shell = True)

def run():
	PRINT_ACTION('Getting the server pcap file while replaying.', 0)
	configs = Configs()
	configs.read_args(sys.argv)
	configs.is_given('pcap_folder')
	configs.show_all()

	pcap_dir = configs.get('pcap_folder')
	pcap_files = []
	for pcap_file in os.listdir('.'):
		if pcap_file.endswith('_out.pcap'):
			pcap_files.append(os.path.abspath('.') + '/' + pcap_file)
			os.system("cp " + pcap_file + " " + pcap_dir + "/" + pcap_file)

	if len(pcap_files) > 1 :
		print '\tThis directory contains more than one "_out.pcap" file!'
		sys.exit(-2)
	elif len(pcap_files) == 0:
		print '\tThis directory has no "_out.pcap" file while replaying!'
		sys.exit(-2)
	else:
		(absolute_path, file_name) = os.path.split(pcap_files[0])
		if DEBUG == 2: print "\t" + file_name

	PRINT_ACTION('Extracting client/server packets from two endpoints respectively. (IP might be different due to NAT/PAT.)',0)
	if DEBUG == 2: print "\tTarget file: " + file_name
	endpoints = extractEndpoints(pcap_dir, file_name)
	client = endpoints[0]
	server = endpoints[1]
	print "\t" + "Client: " + client + " <-> Server: " + server + " from server side"
	splitPcap(pcap_dir, file_name, client, server, 'server')
	
	PRINT_ACTION('Counting all UDP Packets on server side.',0)
	print "\t# of UDP packets collected on server side: " + str(pkt_ctr(pcap_dir, file_name, 'udp'))
	
	PRINT_ACTION('Getting the delay from parsed UDP Packets on server side.',0)
	server_sent = server + "_" + client + "_server_sent.txt" 
	print "\tThere are " + parsedPktCnt(pcap_dir, server_sent) + " packets which server has successfully sent."
	server_rcvd = client + "_" + server + "_server_rcvd.txt" 
	print "\tThere are " + parsedPktCnt(pcap_dir, server_rcvd) + " packets which server has successfully received."
	
	PRINT_ACTION('Getting inter-packet timestamps UDP Packets on server side.',0)
	server_sent_interval = pcap_dir + "/" + server_sent + "_interPacketIntervals.txt"
	server_rcvd_interval = pcap_dir + "/" + server_rcvd + "_interPacketIntervals.txt"
	getTimestamp(pcap_dir, server_sent)
	interPacketSentInterval(pcap_dir, server_sent)
	print "\t" + server_sent_interval + " has been created!"
	getTimestamp(pcap_dir, server_rcvd)
	interPacketSentInterval(pcap_dir, server_rcvd)
	print "\t" + server_rcvd_interval + " has been created!"

	PRINT_ACTION('Receiving the interPacketIntervals files from the client.',0)
	client_sent_interval = pcap_dir + '/' + 'client_sent_interPacketIntervals_rcvd.txt'
	client_rcvd_interval = pcap_dir + '/' + 'client_rcvd_interPacketIntervals_rcvd.txt'
	receivingFile(client_sent_interval)
	print '\tReceived the file from the client.. (' + client_sent_interval + ')'
	receivingFile(client_rcvd_interval)
	print '\tReceived the file from the client.. (' + client_rcvd_interval + ')'
	
	PRINT_ACTION('Calculating the interPacketIntervals at bothendpoints',0)
	udpDelay(pcap_dir, client_sent_interval, client_rcvd_interval, server_sent_interval, server_rcvd_interval)
	
	PRINT_ACTION('Drawing the graph with Gnuplot',0)
	client_delay_sort_cmd = ("sort " + pcap_dir + '/client_delay.txt > ' + pcap_dir + '/client_delay_sorted.txt')
	server_delay_sort_cmd = ("sort " + pcap_dir + '/server_delay.txt > ' + pcap_dir + '/server_delay_sorted.txt')
	os.system(client_delay_sort_cmd)
	os.system(server_delay_sort_cmd)
	writePlotSet(pcap_dir,'client')
	drawPlot(pcap_dir, 'client')
	print '\tPlot has been saved to ' + pcap_dir + '/cdf_udpjitter_client.ps'
	writePlotSet(pcap_dir,'server')
	drawPlot(pcap_dir, 'server')
	print '\tPlot has been saved to ' + pcap_dir + '/cdf_udpjitter_server.ps'
	
	PRINT_ACTION('Done...!!',0)
	
def main():
	run()
	
if __name__=="__main__":
	if len(sys.argv) < 2:
		print "Usage: " + sys.argv[0] + " --pcap_folder = [YOUR_PCAP_FOLDER]"
		print "This program assumes that there exists the file whose name ends with '_out.pcap' in a current directory"
		sys.exit()
	main()
