'''
#######################################################################################################
#######################################################################################################

by: Arash Molavi Kakhki (arash@ccs.neu.edu)
    Northeastern University
    
Goal: this is the client side script for TCP replay.

Usage:
    python tcp_client.py --pcap_folder=../data/dropbox_d --instance=achtung --original_ports=False

#######################################################################################################
#######################################################################################################
'''

import os, sys, socket, pickle, threading, time, ConfigParser
import python_lib 
from python_lib import Configs, PRINT_ACTION

DEBUG0 = False

def read_ports(host, username, key, ports_file):
    """
    If random ports are used on the server side, then the mapping of the ports are
    written to a file on the server side and client needs to download it before 
    starting
    """
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
    """
    This class handles connections to servers.
    
    It basically holds a dictionary which maps c_s_pairs to connections.
    """
    def __init__(self):
        self._connections = {}

    def _port_from_c_s_pair(self, c_s_pair):
        return int((c_s_pair.partition('-')[2]).rpartition('.')[2])
    
    def get_sock(self, c_s_pair):
        '''
        Every time we want to send out a payload on a c_s_pair, we first query its
        corresponding connection. If the connection doesn't exist (very first time we
        are sending a payload on this c_s_pair), it creates the connection.
        '''
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
            
            '''
            Every time a new connection is establishes, before sending any actual data to
            the server, we tell the server which c_s_pair this connection was opend for.
            This is necessary because multiple c_s_pairs might connecto to the same port
            on the server.
            '''
            sock.sendall(c_s_pair)
            
            self.set_sock(c_s_pair, sock)
            return self._connections[c_s_pair]
    
    def set_sock(self, c_s_pair, socket):
        self._connections[c_s_pair] = socket
    
    def remove_socket(self, c_s_pair):
        del self._connections[c_s_pair]
class SendRecv(object):
    """
    This class handles a single request-response event.
    It sends a single request and receives the response for that
    """
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
            if DEBUG0: print '\tWaiting for response', q.c_s_pair, q.response_len
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
    """
    This is the class which sends out the packets in the queue one-by-one.
    Before sending each packets, it makes sure:
        1- All previous packets in the queue are sent
        2- All previous responses on the same connection are received
        3- Packet timestamp has passed (it's time to send the packet)
    
    Once all the above are satisfied, it fires of a thread with target = SendRecv().send_single_request
    """
    def __init__(self, queue):
        '''
        sendlist: before sending a payload, we append the corresponding c_s_pair to this list.
                  Once the payload is fully sent, c_s_pair is poped (happens in send_single_request) 
                  and sendlist becomes empty. In other words, if sendlist is NOT empty, that means we 
                  are in the process of sending a payload and next packet needs to wait.
                  So we use this to satisfy condition "1" mentioned above
        waitlist: it contains c_s_pairs which are waiting for a response. So whenever we send a
                  payload, we add the corresponding c_s_pair to this list. Once the response of 
                  that payload is fully received, c_s_pair is removed from the waitlist.
                  So we use this to satisfy condition "2" mentioned above
        
        '''
        self.Q           = queue
        self.event       = threading.Event()
        self.waitlist    = []
        self.sendlist    = []
        self.time_origin = 0
        self.connections = Connections()
    def next(self, timing):
        if (len(self.sendlist) == 0):
            q = self.Q[0]
            if (q.c_s_pair not in self.waitlist):
                if timing:
                    if time.time() < self.time_origin + q.timestamp:
                        time.sleep((self.time_origin + q.timestamp) - time.time())
                self.Q.pop(0)
                self.waitlist.append(q.c_s_pair)
                self.sendlist.append(q.c_s_pair)
                t = threading.Thread(target=SendRecv().send_single_request, args=[q, self.waitlist, self.sendlist, self.event, self.connections])
                t.start()
    def run(self, timing):
        self.time_origin = time.time()
        while self.Q:
            self.next(timing)
            self.event.wait()
            self.event.clear()  #The loop pauses here and waits for event.set().
                                #event.set() will be done inside send_single_request
def run(argv):
    '''
    ######################################################################################
    Reading/setting configurations
    
    original_ports: if we are using random server ports or original server ports seen in
                    the original pcap
    instance: holds information about the instance the server is running on (see python_lib.py)
    ######################################################################################
    '''
    PRINT_ACTION('Reading configs file and args)', 0)
    configs = Configs()
    configs.set('original_ports', True)
    configs.set('instance', 'meddle')
    configs.set('timing', True)
    
    configs.read_args(sys.argv)
    
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
    
    if not configs.get('original_ports'):
        PRINT_ACTION('Downloading ports file', 0)
        configs.set('ports_file', '/tmp/free_ports')
        os.system('rm -f ' + configs.get('ports_file'))
        configs.set('ports', read_ports(configs.get('instance').host, configs.get('instance').username, configs.get('instance').ssh_key, configs.get('ports_file')))
    
    PRINT_ACTION('Loading the queue', 0)
    queue = pickle.load(open(configs.get('pcap_file') +'_client_pickle', 'rb'))

    PRINT_ACTION('Firing off ...', 0)
    Queue(queue).run(configs.get('timing'))
    configs.reset()
    
def main():
    run(sys.argv)
    
if __name__=="__main__":
    main()
    