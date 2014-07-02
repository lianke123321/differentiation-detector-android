import sys, os, ConfigParser, math, json, time, subprocess, dpkt

def PRINT_ACTION(string, indent, action=True):
    if action:
        print ''.join(['\t']*indent), '[' + str(Configs().action_count) + ']' + string
        Configs().action_count = Configs().action_count + 1
    else:
        print ''.join(['\t']*indent) + string

def append_to_file(line, filename):
    f = open(filename, 'a')
    f.write((line + '\n'))
    f.close()

def print_progress(total_number_of_steps, extra_print=None, width=50):
    '''
    Prints progress bar.
    '''
    current_step = 1
    
    while current_step <= total_number_of_steps:
        sys.stdout.write('\r')
        sys.stdout.write("\t[{}] {}% ({}/{})".format(('='*(current_step*width/total_number_of_steps)).ljust(width)
                                                   , int(math.ceil(100*current_step/float(total_number_of_steps)))
                                                   , current_step
                                                   , total_number_of_steps))
        if extra_print:
            sys.stdout.write(extra_print)
        
        sys.stdout.flush()
        
        if current_step == total_number_of_steps:
            print '\n'
        
        current_step += 1
        yield

def dir_list(dir_name, subdir, *args):
    '''
    Return a list of file names in directory 'dir_name'
    If 'subdir' is True, recursively access subdirectories under 'dir_name'.
    Additional arguments, if any, are file extensions to add to the list.
    Example usage: fileList = dir_list(r'H:\TEMP', False, 'txt', 'py', 'dat', 'log', 'jpg')
    '''
    fileList = []
    for file in os.listdir(dir_name):
        dirfile = os.path.join(dir_name, file)
        if os.path.isfile(dirfile):
            if len(args) == 0:
                fileList.append(dirfile)
            else:
                if os.path.splitext(dirfile)[1][1:] in args:
                    fileList.append(dirfile)
        # recursively access file names in subdirectories
        elif os.path.isdir(dirfile) and subdir:
            # print "Accessing directory:", dirfile
            fileList += dir_list(dirfile, subdir, *args)
    return fileList

def read_client_ip(client_ip_file, follows = False):
    if follows:
        l = linecache.getline((client_ip_file + '/follow-stream-0.txt'), 5)
        return (l.split()[2]).partition(':')[0]
    f = open(client_ip_file, 'r')
    return (f.readline()).strip()

def convert_ip(ip):
    '''
    converts ip.port to tcpflow format
    ip.port = 1.2.3.4.1234
    tcpflow format = 001.002.003.004.01234
    '''
    l     = ip.split('.')
    l[:4] = map(lambda x : x.zfill(3), l[:4])
    l[4]  = l[4].zfill(5)
    return '.'.join(l)

# class UDPQueue(object):
#     def __init__(self, starttime=None, dst_socket=None, c_s_pair=None):
#         self.Q          = []
#         self.c_s_pair   = c_s_pair
#         self.starttime  = starttime
#         self.dst_socket = dst_socket
#         
#     def add_UDPset(self, udp_set):
#         self.Q.append(udp_set)
#         
#     def __str__(self):
#         return (' -- '.join([self.c_s_pair, str(self.starttime), str(self.dst_socket), '\n\t']) +
#                 '\n\t'.join([(udp_set.payload + '\t' + str(udp_set.timestamp)) for udp_set in self.Q]))

class UDPset(object):
    def __init__(self, payload, timestamp, c_s_pair, client_port=None, end=False):
        self.payload     = payload
        self.timestamp   = timestamp
        self.c_s_pair    = c_s_pair
        self.client_port = client_port
        self.end         = end
    def __str__(self):
        return '{}--{}--{}--{}--{}'.format(self.payload, self.timestamp, self.c_s_pair, self.client_port, self.end)
    def __repr__(self):
        return '{}--{}--{}--{}--{}'.format(self.payload, self.timestamp, self.c_s_pair, self.client_port, self.end)
        
class TCP_UDPjsonEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, UDPset):
            obj = {'payload':obj.payload, 'timestamp':obj.timestamp, 'c_s_pair':obj.c_s_pair, 'client_port':obj.client_port, 'end':obj.end}
        elif isinstance(obj, RequestSet):
            obj = {'payload':obj.payload, 'c_s_pair':obj.c_s_pair, 'timestamp':obj.timestamp, 'response_hash':obj.response_hash, 'response_len':obj.response_len}
        elif isinstance(obj, ResponseSet):
            obj = {'request_len':obj.request_len, 'request_hash':obj.request_hash, 'response_list':obj.response_list}
        elif isinstance(obj, OneResponse):
            obj = {'payload':obj.payload, 'payload':obj.payload}
        else:
            obj = super(TCP_UDPjsonEncoder, self).default(obj)
        return obj    

class UDPjsonDecoder_client(json.JSONDecoder):
    def decode(self, json_string):
        default_obj = super(UDPjsonDecoder_client,self).decode(json_string)
        client_Q = []
        for udp in default_obj[0]:
            client_Q.append(UDPset(udp['payload'], udp['timestamp'], udp['c_s_pair'], udp['client_port'], udp['end']))
        return [client_Q] + default_obj[1:]

class UDPjsonDecoder_server(json.JSONDecoder):
    def decode(self, json_string):
        default_obj = super(UDPjsonDecoder_server,self).decode(json_string)
        server_Q = {}
        for server_port in default_obj[0]:
            server_Q[server_port] = []
            for udp in default_obj[0][server_port]:
                server_Q[server_port].append(UDPset(udp['payload'], udp['timestamp'], udp['c_s_pair'], udp['client_port'], udp['end']))
        return [server_Q] + default_obj[1:]

class TCPjsonDecoder_client(json.JSONDecoder):
    def decode(self, json_string):
        default_obj = super(TCPjsonDecoder_client, self).decode(json_string)
        client_Q = []
        for tcp in default_obj[0]:
            req = RequestSet(tcp['payload'], tcp['c_s_pair'], '', tcp['timestamp'])
            req.response_hash = tcp['response_hash']
            req.response_len  = tcp['response_len']
            client_Q.append(req)
        return [client_Q] + default_obj[1:]

class SocketInstance():
    def __init__(self, ip, port, name=None):
        self.ip   = ip
        self.port = port
        self.name = name
    def __str__(self):
        return '{}-{}'.format(self.ip, self.port)

class RequestSet(object):
    '''
    NOTE: These objects are created in the parser and the payload is encoded in HEX.
          However, before replaying, the payload is decoded, so for hash and length,
          we need to use the decoded payload.
    '''
    def __init__(self, payload, c_s_pair, response, timestamp):
        self.payload   = payload
        self.c_s_pair  = c_s_pair
        self.timestamp = timestamp
        
        if response is None:
            self.response_hash = None
            self.response_len  = 0
        else:    
            self.response_hash = hash(response.decode('hex'))
            self.response_len  = len(response.decode('hex'))
    
    def __str__(self):
        return '{} -- {} -- {}'.format(self.payload, self.timestamp, self.c_s_pair)
    
class ResponseSet(object):
    '''
    NOTE: These objects are created in the parser and the payload is encoded in HEX.
          However, before replaying, the payload is decoded, so for hash and length,
          we need to use the decoded payload.
    '''
    def __init__(self, request, response_list):
        self.request_len   = len(request.decode('hex'))
        self.request_hash  = hash(request.decode('hex'))
        self.response_list = response_list
    
    def __str__(self):
        return '{} -- {}'.format(self.request_len, self.response_list)
    
class OneResponse(object):
    def __init__(self, payload, timestamp):
        self.payload   = payload
        self.timestamp = timestamp
        
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

class Instance(object):
    instance_list = {
        '2ec2'    : {'host'     : 'ec2-54-86-43-223.compute-1.amazonaws.com',
                     'username' : 'ubuntu',
                     'ssh_key'  : '~/.ssh/meddle'},
        'meddle'  : {'host'     : 'ec2-54-243-17-203.compute-1.amazonaws.com',
                     'username' : 'ubuntu',
                     'ssh_key'  : '~/.ssh/meddle'},
        'meddle-tun'  : {'host' : '10.101.101.101',
                     'username' : 'ubuntu',
                     'ssh_key'  : '~/.ssh/meddle'},
        'achtung' : {'host'     :'129.10.115.141',
                     'username' : 'arash',
                     'ssh_key'  : '~/.ssh/id_rsa'},
        'alan-ec2': {'host'     :'ec2-54-204-220-73.compute-1.amazonaws.com',
                     'username' : 'ubuntu',
                     'ssh_key'  : '~/.ssh/ancsaaa-keypair_ec2.pem'},
        'localhost': {'host'    :'127.0.0.1',
                     'username' : 'arash',
                     'ssh_key'  : ''},
		'koo'  : {'host'     : 'ec2-54-243-17-203.compute-1.amazonaws.com',
			 'username' : 'ubuntu',
			 'ssh_key'  : ''},
    }
    def __init__(self, instance, instances=instance_list):
        self.name     = instance
        self.host     = instances[instance]['host']
        self.username = instances[instance]['username']
        self.ssh_key  = instances[instance]['ssh_key']
    def __str__(self):
        return '{} -- {} -- {} -- {}'.format(self.name, self.host, self.username, self.ssh_key)

class tcpdump(object):
    '''
    Class for taking tcpdump
    
    Everything is self-explanatory
    '''
    def __init__(self, dump_name=None, interface='en0'):
        self._interface = interface
        self._running   = False
        self._p         = None
        self._plist     = None
        self.dump_name  = None
        
        if dump_name is None:
            self.dump_name = 'dump_' + time.strftime('%Y-%b-%d-%H-%M-%S', time.gmtime()) + '.pcap'
        else:
            self.dump_name = 'dump_' + dump_name + '.pcap'
    
    def start(self, host=None):
        self._plist = ['tcpdump', '-nn', '-i', self._interface, '-w', self.dump_name]
        if host:
            self._plist += ['host', host]
        self._p = subprocess.Popen(self._plist)
        self._running = True
#         print '\nStarted tcpdump: {}'.format(self._plist)
        return self._running
    
    def stop(self):
        self._p.terminate()
        self._running = False
#         print '\tDump stopped: {}'.format(self._interface, self.dump_name, self._p.pid)
        return self._running
    
    def status(self):
        return self._running

def clean_pcap(in_pcap, port_list, out_pcap=None, logfile='clean_pcap_logfile'):
    if out_pcap is None:
        out_pcap = in_pcap.replace('.pcap', '_out.pcap')
    
    filter  = 'port ' + ' or port '.join(map(str, port_list))
    command = ['tcpdump', '-r', in_pcap, '-w', out_pcap, '-R', filter]

    p = subprocess.Popen(command)
    
class ReplayObj(object):
    def __init__(self, id, replay_name, ip, tcpdump_int):
        self.id          = id
        self.replay_name = replay_name
        self.ip          = ip
        self.start_time  = time.strftime("%Y-%m-%d-%H-%M-%S", time.gmtime())
        self.dump        = tcpdump(dump_name='_'.join([id, replay_name, ip, self.start_time]), interface=tcpdump_int)
        self.ports       = []
    
    def get_info(self):
        return '\t'.join([self.id, self.replay_name, self.ip, self.dump.dump_name, self.start_time])
    
    def get_ports(self):
        return self.id + '\t' + ';'.join(self.ports)

############################################
##### ADDED BY HYUNGJOON KOO FROM HERE #####
############################################

# Determines both endpoints
def extractEndpoints(pcap_dir, file_name):
	extract = ("tshark -Tfields -E separator=- -e ip.src -e ip.dst -r " + pcap_dir + "/" + file_name +" | head -1 > " + pcap_dir + "/" + file_name + "_endpoints.txt")
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

# Returns the count of parsed packets
def parsedPktCnt(pcap_dir, endpoint):
	pktCntCmd = ("cat " + pcap_dir + "/" + endpoint + " " + " | wc -l")
	import commands
	pktCnt = commands.getoutput(pktCntCmd)
	return pktCnt

# Extracts the timestamps for the endpoint to calculate jitter
def getTimestamp(pcap_dir, endpoint):
	getTimestampCmd = ("cat " + pcap_dir + "/" + endpoint + " | awk '{print $2}' > " + pcap_dir + "/" + "ts_" + endpoint + ".tmp")
	os.system(getTimestampCmd)

# Saves the inter-packet intervals between when to sent
def interPacketSentInterval(pcap_dir, endpoint):
	tmp = open(pcap_dir + '/ts_' + endpoint + '.tmp','r')
	timestamps = tmp.read().splitlines()
	intervals = []
	i = 0
	ts_cnt = len(timestamps)
	while (i < ts_cnt - 1):
		intervals.append(format_float(float(timestamps[i+1]) - float(timestamps[i]),15))
		i = i + 1
	f = open(pcap_dir + '/' + endpoint + '_interPacketIntervals.txt', 'w')
	f.write('\n'.join(str(ts) for ts in intervals))
	os.system('rm -f ' + pcap_dir + '/ts_' + endpoint + '.tmp')

# Helps to write float format by removing characters
def format_float(value, precision=-1):
    if precision < 0:
        f = "%f" % value
    else:
        f = "%.*f" % (precision, value)
    p = f.partition(".")
    s = "".join((p[0], p[1], p[2][0], p[2][1:].rstrip("0")))
    return s
