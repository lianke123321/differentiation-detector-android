'''
by: Arash Molavi Kakhki (arash@ccs.neu.edu)
    Northeastern University
    
Goal: this is the client side script for our replay system.

Input: a config_file

queue = [ [pl, c-s-pair, hash(response), len(response)], ... ]

'''

import os, sys, socket, pickle, threading, time
from python_lib import * 

def read_ports(ports_pickle_dump):
    if ports_pickle_dump == None:
        ports_pickle_dump = 'achtung.ccs.neu.edu:/home/arash/public_html/free_ports'
    os.system(('scp ' + ports_pickle_dump + ' .'))
    return pickle.load(open('free_ports', 'rb'))
class Connections(object):
    _instance = None
    _host     = None
    _ports    = None
    connections = {}
#    def __new__(cls, *args, **kwargs):
#        if not cls._instance:
#            cls._instance = super(Connections, cls).__new__(cls, *args, **kwargs)
#        return cls._instance
#    
#    def __init__(self):
#        self.connections = {}
    
    @staticmethod
    def get_sock(c_s_pair):
        try:
            return Connections.connections[c_s_pair]
        except:
#            print 'get_sock', c_s_pair, Connections._ports[c_s_pair]
            server_address = (Connections._host, Connections._ports[c_s_pair])
            
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
            sock.connect(server_address)
            
            Connections.set_sock(c_s_pair, sock)
            return Connections.connections[c_s_pair]
    
    @staticmethod
    def set_sock( c_s_pair, socket):
        Connections.connections[c_s_pair] = socket
    
    @staticmethod
    def remove_connection(c_s_pair):
        del Connections.connections[c_s_pair]
    
    @staticmethod
    def set_host(host):
        Connections._host = host
    @staticmethod
    def set_ports(ports):
        Connections._ports = ports
        
class SendRecv(object):
    def __init__(self, q):
        self.payload   = q[0]
        self.c_s_pair  = q[1]
        self.res_hash  = q[2]
        self.res_len   = q[3]
        self.timestamp = q[4]
        
    def send_single_request(self, waitlist, sendlist, event):
        sock = Connections.get_sock(self.c_s_pair)
#        print 'Sending:', self.c_s_pair, '\t', sock, '\t', len(self.payload) 
        sock.sendall(self.payload)
        
        sendlist.pop()
        if self.res_len == 0:
#            print '\tNoResponse', self.c_s_pair, '\t', len(self.payload)
            waitlist.remove(self.c_s_pair)
            event.set()
        else:
#            print '\tWaiting for responce', self.c_s_pair, self.res_len
            event.set()
            buffer_len = 0
            while True:
                buffer_len += len(sock.recv(4096))
                if buffer_len == self.res_len:
                    break
#            print '\tReceived', self.c_s_pair, '\t', buffer_len
            waitlist.remove(self.c_s_pair)
            event.set()
        
class Queue(object):
    i = 1
    def __init__(self, queue):
        self.Q           = queue
        self.event       = threading.Event()
        self.waitlist    = []
        self.sendlist    = []
        self.time_origin = 0
    def next(self):
        #print 'sendlist:', self.sendlist
        if (len(self.sendlist) == 0):
            #print 'Ready to send...'
            q           = self.Q[0]
            q_payload   = q[0]
            q_c_s_pair  = q[1]
            q_res_hash  = q[2]
            q_res_len   = q[3]
            q_timestamp = q[4]
            
            if (q_c_s_pair not in self.waitlist):
                if time.time() > self.time_origin + q_timestamp:
#                    print time.time() - (self.time_origin + q_timestamp) 
                    time.sleep(time.time()-self.time_origin + q_timestamp)
                self.Q.pop(0)
                self.waitlist.append(q_c_s_pair)
                self.sendlist.append(q_c_s_pair)
                t = threading.Thread(target=SendRecv(q).send_single_request, args=[self.waitlist, self.sendlist, self.event])
                self.i += 1
                t.start()
    def run(self):
        self.time_origin = time.time()
        while self.Q:
            #print 'Doing:', self.i
            self.next()
            #print 'Sleeping!'
            self.event.wait()
            #print 'Woke up!'
            self.event.clear()
            
def main():
    
    DEBUG = False
    
    try:
        pcap_folder = sys.argv[1]
    except:
        print 'USAGE: python tcp_client.py [pcap_folder]'   
        sys.exit(-1)
    
    pcap_folder = os.path.abspath(pcap_folder)
    config_file = pcap_folder + '/' + os.path.basename(pcap_folder) + '.pcap_config'
    
#    configs.Configs.set('pcap_folder', os.path.abspath(pcap_folder))
#    configs.Configs.set('config_file', os.path.abspath(pcap_folder))
    
    [All_Hash, pcap_file, number_of_servers] = read_config_file(config_file)
    print 'All_Hash         :', All_Hash
    print 'pcap_file        :', pcap_file
    print 'number_of_servers:', number_of_servers
    
    '''Defaults'''
    port_file = None
    host = '129.10.115.141'
    
    
    for arg in sys.argv:
        a = (arg.strip()).partition('=')
        if a[0] == 'port_file':
            port_file = a[2]
        if a[0] == 'host':
            host = a[2]
    
    ports = read_ports(port_file)    
    queue = pickle.load(open(pcap_file +'_client_pickle', 'rb'))


    Connections.set_host(host)
    Connections.set_ports(ports)


    Queue(queue).run()
        
    
if __name__=="__main__":
    main()
    
    
    