'''
by: Arash Molavi Kakhki (arash@ccs.neu.edu)
    Northeastern University
    
Goal: this is the client side script for our replay system.

Input: a config_file

queue = [ [pl, c-s-pair, hash(response), len(response)], ... ]

python tcp_client.py ../data/youtube_d host=ec2-72-44-56-209.compute-1.amazonaws.com ports_file='-i /Users/arash/.ssh/ancsaaa-keypair_ec2.pem ubuntu@72.44.56.209:/home/ubuntu/public_html/free_ports'

'''

import os, sys, socket, pickle, threading, time, ConfigParser
import python_lib 
from python_lib import Configs, PRINT_ACTION

DEBUG0 = False

def read_ports(host, username, key, ports_file):
    if key is not None:
        command = 'scp -i ' + key + ' '
    if username is not None:
        command += username + '@'
    else:
        command = 'scp '
    command += host + ':' + ports_file + ' .'
    os.system(command)
    return pickle.load(open('free_ports', 'rb'))
class Connections(object):
    def __init__(self):
        self._connections = {}

    def _port_from_c_s_pair(self, c_s_pair):
        return int((c_s_pair.partition('-')[2]).rpartition('.')[2])
    
    def get_sock(self, c_s_pair):
        try:
            return self._connections[c_s_pair]
        except:
            if Configs().get('original_ports'):
                server_address = (Configs().get('instance').host, self._port_from_c_s_pair(c_s_pair))
            else:
                server_address = (Configs().get('instance').host, Configs().get('ports')[c_s_pair])
            print '\tStarting:', server_address
            print '           ', c_s_pair
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
            sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)

            sock.connect(server_address)
            sock.sendall(c_s_pair)
            
            self.set_sock(c_s_pair, sock)
            return self._connections[c_s_pair]
    
    def set_sock(self, c_s_pair, socket):
        self._connections[c_s_pair] = socket
    
    def remove_socket(self, c_s_pair):
        del self._connections[c_s_pair]
class SendRecv(object):        
    def send_single_request(self, q, waitlist, sendlist, event, connections):
        sock = connections.get_sock(q.c_s_pair)
        if DEBUG0: print 'Sending:', q.c_s_pair, '\t', sock, '\t', len(q.payload)
        sock.sendall(q.payload)
        
        sendlist.pop()
        if q.response_len == 0:
            if DEBUG0: print '\tNoResponse', q.c_s_pair, '\t', len(q.payload)
            waitlist.remove(q.c_s_pair)
            event.set()
        else:
            if DEBUG0: print '\tWaiting for responce', q.c_s_pair, q.response_len
            event.set()
            buffer_len = 0
            while True:
                buffer_len += len(sock.recv(4096))
                if buffer_len == q.response_len:
                    break
            if DEBUG0: print '\tReceived', q.c_s_pair, '\t', buffer_len
            waitlist.remove(q.c_s_pair)
            event.set()        
class Queue(object):
    def __init__(self, queue):
        self.Q           = queue
        self.event       = threading.Event()
        self.waitlist    = []
        self.sendlist    = []
        self.time_origin = 0
        self.connections = Connections()
    def next(self):
        if (len(self.sendlist) == 0):
            q = self.Q[0]
            if (q.c_s_pair not in self.waitlist):
                if time.time() < self.time_origin + q.timestamp:
                    time.sleep((self.time_origin + q.timestamp) - time.time())
                self.Q.pop(0)
                self.waitlist.append(q.c_s_pair)
                self.sendlist.append(q.c_s_pair)
                t = threading.Thread(target=SendRecv().send_single_request, args=[q, self.waitlist, self.sendlist, self.event, self.connections])
                t.start()
    def run(self):
        self.time_origin = time.time()
        while self.Q:
            self.next()
            self.event.wait()
            self.event.clear()
def run(argv):
    PRINT_ACTION('Reading configs file and args)', 0)
    configs = Configs()
    configs.set('original_ports', True)
    #Add your instance to Instance class in python_lib.py
    configs.set('instance', 'meddle')
    
    python_lib.read_args(argv, configs)
    
    try:
        pcap_folder = os.path.abspath(configs.get('pcap_folder'))
    except:
        print 'USAGE: python tcp_client.py pcap_folder=[]'
        print '\tpcap_folder should contain the following files:'
        print '\tconfig_file, client_pickle_dump, server_pickle_dump'
        sys.exit(-1)

    configs.read_config_file((pcap_folder + '/' + os.path.basename(pcap_folder) + '.pcap_config'))    
    
    configs.set('instance', python_lib.Instance(configs.get('instance')))
    configs.show_all()
    configs.get('instance').show()
    
    if not configs.get('original_ports'):
        PRINT_ACTION('Downloading ports file', 0)
        configs.set('ports_file', '/tmp/free_ports')
        os.system('rm -f ' + configs.get('ports_file'))
        configs.set('ports', read_ports(configs.get('instance').host, configs.get('instance').username, configs.get('instance').ssh_key, configs.get('ports_file')))
    
    PRINT_ACTION('Loading the queue', 0)
    queue = pickle.load(open(configs.get('pcap_file') +'_client_pickle', 'rb'))

    PRINT_ACTION('Firing off ...', 0)
    Queue(queue).run()
    configs.reset()
    
def main():
    run(sys.argv)
    
if __name__=="__main__":
    main()
    