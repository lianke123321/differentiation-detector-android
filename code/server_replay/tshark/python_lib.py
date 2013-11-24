import socket, sys, subprocess, commands, os, ConfigParser

def socket_disconnect(sock):
    print 'Closing socket:', sock
    sock.shutdown(socket.SHUT_RDWR)
    sock.close()
    print 'Done'
def update_state(who, payload, state, snd_rcv):
    if who not in state:
        state[who] = {'sent' : None, 'rcvd' : None}
    state[who][snd_rcv] = hash(payload)
def check_events(event_list, state):
    if event_list is None:
        return True
    try:
        for e in event_list:
            if e is None:
                continue
            if (state[e[1]][e[2]] == e[0]) is False: 
                return False
        return True 
    except:
        return False
def get_all_tcp_servers(pcap_file, client_ip):
    ips = [client_ip]
    tcp_c = 0
    a = rdpcap(pcap_file)
    for i in range(len(a)):
        p = a[i]
        try:
            tcp = p['IP']['TCP']
            tcp_c += 1
            try:
                raw = p['Raw'].load
                if p['IP'].src not in ips:
                    ips.append(p['IP'].src)
                if p['IP'].dst not in ips:
                    ips.append(p['IP'].dst)
            except:
                pass
        except:
            pass
    print 'Number of packets:', len(a)
    print 'Number of TCP packets:', tcp_c
    for ip in ips:
        print ip
def append_to_file(line, filename):
    f = open(filename, 'a')
    f.write((line + '\n'))
    f.close()
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
class RequestSet(object):
    def __init__(self, payload, c_s_pair, response, timestamp):
        self.payload  = payload
        self.c_s_pair = c_s_pair
        if response is None:
            self.response_hash = None
            self.response_len  = 0
        else:    
            self.response_hash = hash(response)
            self.response_len  = len(response)
        self.timestamp = timestamp
class ResponseSet(object):
    def __init__(self, request, response_list):
        self.request_len   = len(request)
        self.request_hash  = hash(request)
        self.response_list = response_list
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
    __metaclass__ = Singleton
    _configs      = {}
    def __init__(self, config_file):
        Config = ConfigParser.ConfigParser()
        Config.read(config_file)
        for section in Config.sections():
            for option in Config.options(section):
                self._configs[option] = Config.get(section, option)
    def get(self, key):
        return self._configs[key]
    def set(self, key, value):
        self._configs[key] = value
    def show(self, key):
        print key , ':\t', value
    def show_all(self):
        for key in self._configs:
            print key , ':\t', self._configs[key]
