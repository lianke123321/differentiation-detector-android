'''
#######################################################################################################
#######################################################################################################

by: Hyungjoon Koo (hykoo@cs.stonybrook.edu)
    Stony Brook University

Goal: calculate udp jitter between client and server
Required package: dpkt (https://code.google.com/p/dpkt/)

Usage:
    python udp_jitter_client.py --pcap_folder=[]
	
Example:
    python udp_jitter_client.py--pcap_folder=./udp

#######################################################################################################
#######################################################################################################
'''
import sys
import time
from python_lib import *
import dpkt
import socket

DEBUG = 0
# HOST = 'ec2-54-243-17-203.compute-1.amazonaws.com'
HOST = '127.0.0.1'
PORT = 12345

# Extracts two files containing the packets which client sent and which received from server respectively
def splitPcap(pcap_dir, file_name, client, server, description):
	split_cs = ("tshark -r \"" + pcap_dir + "/" + file_name + "\" | grep \"" + client + " -> " + server + "\" > " + pcap_dir + "/" + client + "_" + server + "_" + description + "_sent.txt")
	os.system(split_cs)
	split_sc = ("tshark -r \"" + pcap_dir + "/" + file_name + "\" | grep \"" + server + " -> " + client + "\" > " + pcap_dir + "/" + server + "_" + client + "_" + description + "_rcvd.txt")
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

def parsedPktCnt(pcap_dir, client):
	pktCntCmd = ("cat " + pcap_dir + "/" + client + " " + " | wc -l")
	if DEBUG == 2: print "\t" + pktCntCmd
	import commands
	pktCnt = commands.getoutput(pktCntCmd)
	return pktCnt

def getTimestamp(pcap_dir, client):
	getTimestampCmd = ("cat " + pcap_dir + "/" + client + " | awk '{print $2}' > " + pcap_dir + "/" + "ts_" + client + ".tmp")
	if DEBUG == 2: print "\t" + getTimestampCmd
	os.system(getTimestampCmd)

def interPacketSentInterval(pcap_dir, client):
	tmp = open(pcap_dir + '/ts_' + client + '.tmp','r')
	timestamps = tmp.read().splitlines()
	
	intervals = []
	i = 0
	ts_cnt = len(timestamps)
	while (i < ts_cnt - 1):
		intervals.append(float(timestamps[i+1]) - float(timestamps[i]))
		i = i + 1
	
	f = open(pcap_dir + '/' + client + '_interPacketIntervals.txt', 'w')
	f.write('\n'.join(str(ts) for ts in intervals))
	
	os.system('rm -f ' + pcap_dir + '/ts_' + client + '.tmp')
'''

def sendingFile(file_sent):
	BLOCKSIZE = 8192
	s = None

	try:
		s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
	except socket.error as err_msg:
		s = None
	try:
		s.connect((HOST,PORT))
	except socket.error as err_msg:
		s.close()
		s = None

	if s is None:
		print '\tThe socket has a problem. Check it out!'
		print '\tFYI, This program only supports IPv4.'
		sys.exit(1)

	f = open(file_sent,'rb')
	dataPkt = f.read(BLOCKSIZE)

	while dataPkt !='':
		s.send(dataPkt)
		dataPkt = f.read(BLOCKSIZE)

	s.close()

def run():
	PRINT_ACTION('Getting the client pcap file while replaying.', 0)

	configs = Configs()
	configs.read_args(sys.argv)
	configs.is_given('pcap_folder')
	configs.show_all()

	pcap_dir = configs.get('pcap_folder')
	
	pcap_files = []
	for pcap_file in os.listdir('.'):
		if pcap_file.endswith('client.pcap'):
			pcap_files.append(os.path.abspath('.') + '/' + pcap_file)
			os.system("cp " + pcap_file + " " + pcap_dir + "/" + pcap_file)

	if len(pcap_files) > 1 :
		print '\tThis directory contains more than one pcap file!'
		sys.exit(-2)
	elif len(pcap_files) == 0:
		print '\tThis directory has no pcap file captured on client side!'
		sys.exit(-2)
	else:
		(absolute_path, file_name) = os.path.split(pcap_files[0])
		if DEBUG == 2: print "\t" + file_name

	PRINT_ACTION('Extracting client/server packets from two endpoints respectively. (IP might be different due to NAT/PAT.)',0)
	if DEBUG == 2: print "\tTarget file: " + file_name
	endpoints = extractEndpoints(pcap_dir, file_name)
	client = endpoints[0]
	server = endpoints[1]
	print "\t" + "Client: " + client + " <-> Server: " + server + " from client side"
	splitPcap(pcap_dir, file_name, client, server, 'client')
	
	# PRINT_ACTION('Counting all UDP Packets on client side.',0)
	# print "\t# of UDP packets collected on client side: " + str(pkt_ctr(pcap_dir, file_name, 'udp'))
	
	PRINT_ACTION('Getting the delay from parsed UDP Packets on client side.',0)
	client_sent = client + "_" + server + "_client_sent.txt" 
	print "\tThere are " + parsedPktCnt(pcap_dir, client_sent) + " packets which client has successfully sent."
	client_rcvd = server + "_" + client + "_client_rcvd.txt" 
	print "\tThere are " + parsedPktCnt(pcap_dir, client_rcvd) + " packets which client has successfully received."
	
	PRINT_ACTION('Getting inter-packet timestamps UDP Packets on client side.',0)
	getTimestamp(pcap_dir, client_sent)
	interPacketSentInterval(pcap_dir, client_sent)
	print "\t" + pcap_dir + "/" + client_sent + "_interPacketIntervals.txt has been created!"
	getTimestamp(pcap_dir, client_rcvd)
	interPacketSentInterval(pcap_dir, client_rcvd)
	print "\t" + pcap_dir + "/" + client_rcvd + "_interPacketIntervals.txt has been created!"

	PRINT_ACTION('Sending the interPacketIntervals files to the server. (Make sure the server is ready!)',0)
	file1 = pcap_dir + '/' + client_sent + '_interPacketIntervals.txt'
	sendingFile(file1)
	print '\tSent the file to the server successfully.. (' + file1 + ')'
	os.system('sleep 2')
	file2 = pcap_dir + '/' + client_rcvd + '_interPacketIntervals.txt'
	sendingFile(file2)
	print '\tSent the file to the server successfully.. (' + file2 + ')'
	
def main():
	run()
	
if __name__=="__main__":
	if len(sys.argv) < 2:
		print "Usage: " + sys.argv[0] + " --pcap_folder = [YOUR_PCAP_FOLDER]"
		sys.exit()
	main()
