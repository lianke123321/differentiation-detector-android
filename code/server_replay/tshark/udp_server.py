'''
#######################################################################################################
#######################################################################################################

by: Arash Molavi Kakhki (arash@ccs.neu.edu)
    Northeastern University
    
Goal: server script for UDP replay

Usage:
    python udp_server.py --pcap_folder=[]

Mandatory:
    --pcap_folder: either path to a parsed folder, or a text file where each line is path to a 
                   parsed folder

Optional:
    --original_ports: if true, uses same server ports as seen in the original pcap
                      default: False
    --timing: if true, it respect inter-packet timings seen in the original pcap
              default: True

To kill the server:  
    ps aux | grep "python udp_server.py" |  awk '{ print $2}' | xargs kill -9
#######################################################################################################
#######################################################################################################
'''

import sys, socket, threading, time, multiprocessing, numpy, select, traceback, pickle
from python_lib import *

DEBUG = 5

class UDPServer(object):
    def __init__(self, instance, original_ports):
        self.instance = instance
        self.original_port = self.instance.port
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        
        if not original_ports:
            port = 7600
            while True:
                try:
                    self.sock.bind((self.instance.ip, port))
                    break
                except:
                    port += 1
            self.instance.port = port
            
        else:
            self.sock.bind((self.instance.ip, self.instance.port))

        print '\tCreated server at: {} (original port: {})'.format(instance, self.original_port)
            
    def run(self, mapping, Qs, queue, timing):
        '''
        It runs the UDP server.
        
        Every time a packet comes in:
        
            - If the IP is not in mapping --> it's a new client, add it to mapping
            - If mapping[client_ip][client_port] doesn't exist, it's a new client socket declaring, 
              its c_s_pair. Add it to mapping and put it on the queue so the client is acknowledged.
              Note: when a client socket send a packet for the very first time, the 
                    content is: id;c_s_pair;replay_name
            - If mapping[client_ip][client_port] == (None, None, None) --> Already started sending 
              packets to this client socket, so do nothing
            - Else fire off send_Q to send packets to this client socket and set the mapping
              to (None, None, None).
            
        mapping[client_ip][client_port] = (id, c_s_pair, replay_name) or (None, None, None) if already taken care of
        '''
        while True:
            data, client_address = self.sock.recvfrom(4096)
            
            client_ip   = client_address[0]
            client_port = str(client_address[1]).zfill(5)
            
            if DEBUG == 1: print 'got:', data, client_ip, client_port
            if DEBUG == 3: print 'got:', len(data), 'from', client_ip, client_port
            
            if client_ip not in mapping:
                mapping[client_ip] = {}
            
            try:
                (id, c_s_pair, replay_name) = mapping[client_ip][client_port]
                if c_s_pair is None:
                    continue
                mapping[client_ip][client_port] = (None, None, None)
                p = multiprocessing.Process(target=self.send_Q(Qs[replay_name][c_s_pair], time.time(), client_address, queue, id, timing))
                p.start()
            
            except KeyError, e:
                print e
                if DEBUG == 1: print 'New port:', client_address, data
                data        = data.split(';')
                id          = data[0]
                c_s_pair    = data[1]
                replay_name = data[2]
                mapping[client_ip][client_port] = (id, c_s_pair, replay_name)
                print 'got:', (id, c_s_pair, replay_name)
                queue.put((id, client_port))
                
    def send_Q(self, Q, time_origin, client_address, queue, id, timing):
        '''
        Sends a queue of UDP packets to client socket
        Once done, put on queue to notify client
        '''
        for udp_set in Q:
            if timing:
                if time.time() < time_origin + udp_set.timestamp:
                    try:
                        time.sleep((time_origin + udp_set.timestamp) - time.time())
                    except:
                        pass
            self.sock.sendto(udp_set.payload, client_address)
            if DEBUG == 1: print '\tsent:', udp_set.payload, 'to', client_address
            if DEBUG == 3: print '\tsent:', len(udp_set.payload), 'to', client_address
        
        queue.put((id, client_address[1]))
        
    def terminate(self):
        self.sock.close()

class SideChannel(object):
    def __init__(self, instance, port_map):
        self.connection_map  = {}
        self.sock = self.create_socket(instance)
        self.port_map_pickle = pickle.dumps(port_map, 2)
    
    def create_socket(self, instance):
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
        sock.bind((instance.ip, instance.port))
        sock.listen(1)
        return sock
    
    def run(self, notify_queue, map_cleaner_queue):
        '''
        SideChannel has two main method that should be always running
        
            1- wait_for_connections: every time a new connection comes in, it dispatches a 
               thread with target=handle_connection to take care of the connection.
            2- notify: constantly gets jobs from a queue and notifies clients.
               This could be acknowledgment of new port (coming from UDPServer.run) or 
               notifying of a send_Q end.
        '''
        
        t1 = threading.Thread(target=self.wait_for_connections, args=(map_cleaner_queue,))
        t2 = threading.Thread(target=self.notify, args=(notify_queue,))        
        map(lambda t: t.start(), [t1, t2])
        
    def notify(self, notify_queue):
        while True:
            data = notify_queue.get()
            id   = data[0]
            port = data[1]
            if DEBUG==1: print '\tNOTIFYING:', data, str(port).zfill(5)
            self.connection_map[id].sendall(str(port).zfill(5))
            
    def wait_for_connections(self, map_cleaner_queue):
        while True:
            connection, client_address = self.sock.accept()
            t = threading.Thread(target=self.handle_connection, args=(connection, map_cleaner_queue,))
            t.start()
    
    def handle_connection(self, connection, map_cleaner_queue):
        '''
        STEP1: receive client id (10 bytes) and updatede connection_map
        STEP2: send port mapping to client (if not using original ports)
        STEP3: receives the list of ports that client is done with so it can close them
        STEP4: cleans connection_map and mapping (using the queue)
        '''
        id = connection.recv(10)
        self.connection_map[id] = connection
        
        if Configs().get('original_ports'):
            pickle_size = '0'.ljust(10)
            connection.sendall(pickle_size)
        else:
            pickle_size = str(len(self.port_map_pickle)).ljust(10)
            connection.sendall(pickle_size)
            connection.sendall(self.port_map_pickle)
        
        data = ''
        while True:
            data += connection.recv(4096)
            if data[-3:] == 'FIN':
                break
        data = data.split(';')
        map_cleaner_queue.put( (connection.getpeername()[0], data[:-1]) )
        print self.connection_map
        del self.connection_map[id]
        print self.connection_map
        
    def terminate(self):
        self.sock.close()

def map_cleaner(mapping, map_cleaner_queue):
    '''
    This acts as a garbage collector which removes elements of mapping when no longer needed.
    '''
    while True:
        data = map_cleaner_queue.get()
        client_ip = data[0]
        ports     = data[1]
        
        print mapping
        
        for port in ports:
            del mapping[client_ip][port]

        if len(mapping[client_ip]) == 0:
            del mapping[client_ip]
        
        print mapping
        
def create_test_Qs(ports):
    '''
    ###########################################################################
    Making a test random Q
    
    Qs[c_s_pair] = [UDPset, UDPset, ...]

    UDPset --> payload, timestamp
    ########################################################################### 
    '''
    Q         = {}
    test_count = 5
    ports      = [55055, 55056, 55057]
    
    for i in range(len(ports)):
        port = ports[i]
        c_s_pair = 'XXX.XXX.XXX.XXX.XXXXX-XXX.XXX.XXX.XXX.' + str(port)
        timestamps = sorted([abs(numpy.random.normal(loc=1, scale=1, size=None)) for k in range(test_count)])
        Q[c_s_pair] = []
        
        for j in range(test_count):
            payload = str(i) + '-' + str(j)
            Q[c_s_pair].append(UDPset(payload, timestamps[j], c_s_pair))
    
    for c_s_pair in Q:
        print '\t', Q[c_s_pair]
    
    Qs = {}
    Qs['test'] = Q
    return Qs, ports

def load_Qs(pcap_folder):
    Qs      = {}
    ports   = set()
    folders = []
    
    if os.path.isfile(pcap_folder):
        with open(pcap_folder, 'r') as f:
            for l in f:
                folders.append(l.strip())
    else:
         folders.append(pcap_folder)
    
    for folder in folders:
        if folder == '':
            continue
        
        for file in os.listdir(folder):
            if file.endswith('_server_pickle'):
                pickle_file = os.path.abspath(folder) + '/' + file
                break
        
        Q, server_ports, replay_name = pickle.load(open(pickle_file, 'rb'))
        Qs[replay_name] = Q
        
        for port in server_ports:
            ports.add(port)
        PRINT_ACTION('Created servers for: ' + replay_name, 1, action=False)
    
    return Qs, ports    
    
def main():
    PRINT_ACTION('Creating variables', 0)
    ip = ''
    sidechannel_port = 55555
    notify_queue      = multiprocessing.Queue() #Queue used to notify clients that server is done sending
    map_cleaner_queue = multiprocessing.Queue() #Queue used to notify servers that client is done and can be removed from mapping
    Qs       = {}   #Qs[replay_name] = {c_s_pair: Q, ...}
    mapping  = {}   #mapping[client_ip][client_port] = (id, c_s_pair, replay_name)
    port_map = {}   #port_map[server.original_port] = server.instance.port 

    PRINT_ACTION('Reading configs and args', 0)
    configs = Configs()
    configs.set('original_ports', False)
    configs.set('timing', True)
    configs.read_args(sys.argv)
    configs.show_all()
    
    PRINT_ACTION('Loading server queues', 0)
    Qs, server_ports = load_Qs(configs.get('pcap_folder'))
#    Qs, server_ports = create_test_Qs(ip)
        
    PRINT_ACTION('Firing off map_cleaner', 0)
    t = threading.Thread(target=map_cleaner, args=[mapping, map_cleaner_queue])
    t.start()
    
    PRINT_ACTION('Creating and running UDP servers', 0)
    for port in server_ports:
        server = UDPServer(SocketInstance(ip, int(port)), configs.get('original_ports'))
        port_map[server.original_port] = server.instance.port
        t = threading.Thread(target=server.run, args=[mapping, Qs, notify_queue, configs.get('timing')])
        t.start()

    PRINT_ACTION('Creating and running the side channel', 0)
    side_channel = SideChannel(SocketInstance(ip, sidechannel_port), port_map)
    side_channel.run(notify_queue, map_cleaner_queue)
    
    PRINT_ACTION('READY! You can now run the client script', 0)
    
if __name__=="__main__":
    main()
    