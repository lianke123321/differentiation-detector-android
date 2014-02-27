'''
#######################################################################################################
#######################################################################################################

by: Arash Molavi Kakhki (arash@ccs.neu.edu)
    Northeastern University
    
Goal: server script for UDP replay

Usage:
    python udp_server.py
    
ps aux | grep "python udp_server.py" |  awk '{ print $2}' | xargs kill -9
#######################################################################################################
#######################################################################################################
'''
import sys, socket, threading, time, multiprocessing, numpy, select, traceback

from python_lib import *

DEBUG = 2

class UDPServer(object):
    def __init__(self, instance):
        self.instance = instance
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.sock.bind((self.instance.ip, self.instance.port))
        print '\tCreated server at:', instance
            
    def run(self, mapping, Qs, queue, timing):
        '''
        It runs the UDP server.
        
        Every time a packet comes in:
        
            - If the IP is not in mapping --> it's a new client, add it to mapping
            - If mapping[client_ip][client_port] doesn't exist, it's a new client socket declaring, 
              its c_s_pair. Add it to mapping and put it on the queue so the client is acknowledged.
              Note: when a client socket send a packet for the very first time, the 
                    content is: id;c_s_pair
            - If mapping[client_ip][client_port] == (None, None) --> Already started sending 
              packets to this client socket, so do nothing
            - Else fire off send_Q to send packets to this client socket and set the mapping
              to (None, None).
            
        mapping[client_ip][client_port] = c_s_pair (or None if already taken care of)
        '''
        while True:
            data, client_address = self.sock.recvfrom(4096)
            
            client_ip   = client_address[0]
            client_port = str(client_address[1]).zfill(5)
            
            print 'got:', data
            
            if client_ip not in mapping:
                mapping[client_ip] = {}
            
            try:
                (id, c_s_pair) = mapping[client_ip][client_port]
                if c_s_pair is None:
                    continue
                mapping[client_ip][client_port] = (None, None)
                p = multiprocessing.Process(target=self.send_Q(Qs[c_s_pair], time.time(), client_address, queue, id, timing))
                p.start()
            
            except KeyError:
                if DEBUG == 1: print 'New port:', client_address, data
                data     = data.split(';')
                id       = data[0]
                c_s_pair = data[1]
                mapping[client_ip][client_port] = (id, c_s_pair)
                queue.put((id, client_port))
                
    def send_Q(self, Q, time_origin, client_address, queue, id, timing):
        '''
        Sends a queue of UDP packets to client socket
        Once done, put on queue to notify client
        '''
        if timing:
            if time.time() < time_origin + Q.starttime:
                time.sleep((time_origin + Q.starttime) - time.time())
        
        for i in range(len(Q.Q)):
            udp_set = Q.Q[i]
            if timing:
                if time.time() < time_origin + udp_set.timestamp:
                    time.sleep((time_origin + udp_set.timestamp) - time.time())
            self.sock.sendto(udp_set.payload, client_address)
            print '\tsent:', udp_set.payload
        
        queue.put((id, client_address[1]))
        
    def terminate(self):
        self.sock.close()

class SideChannel(object):
    def __init__(self, instance):
        self.connection_map  = {}
        self.sock = self.create_socket(instance)
    
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
        id = connection.recv(10)
        self.connection_map[id] = connection
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
    This acts as a grabage collector which removes elements of mapping when no longer needed.
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
    
    Qs[c_s_pair] = UDPQueue
    
    UDPQueue --> Q, c_s_pair, starttime, dst_socket
                 Q = [UDPset]
                 UDPset --> payload, timestamp
    ########################################################################### 
    '''
    Qs         = {}
    test_count = 5
    ports      = [55055, 55056, 55057]
    
    for i in range(len(ports)):
        port = ports[i]
        c_s_pair = 'XXX.XXX.XXX.XXX.XXXXX-XXX.XXX.XXX.XXX.' + str(port)
        timestamps = sorted([abs(numpy.random.normal(loc=1, scale=1, size=None)) for i in range(test_count+1)])
        
        queue = UDPQueue(starttime  = timestamps[0],
                         dst_socket = None,
                         c_s_pair   = c_s_pair)
        
        for j in range(test_count):
            payload   = ''.join([c_s_pair , '_SERVER_' , str(j)])
            queue.Q.append(UDPset(payload, timestamps[j+1], c_s_pair))
        Qs[c_s_pair.ljust(43)] = queue
    
    for c_s_pair in Qs:
        print '\t', Qs[c_s_pair]
    
    return Qs, ports


def main():
    PRINT_ACTION('Creating test Qs', 0)
    ip = ''
    sidechannel_port = 55555
    
    Qs, ports = create_test_Qs(ip)
    
    '''
    ###########################################################################
    mapping: mapping[client_ip][port] = c_s_pair
             Gets populated by servers is UDPServer.run (see description of run())
    ###########################################################################
    '''
    
    PRINT_ACTION('Reading configs file and args)', 0)
    configs = Configs()
    configs.set('original_ports', True)
    configs.set('timing', True)
    configs.read_args(sys.argv)
    configs.show_all()

    PRINT_ACTION('Creating variables', 0)
    threads = []
    servers = []
    mapping = {}
    notify_queue      = multiprocessing.Queue()
    map_cleaner_queue = multiprocessing.Queue()
    
    PRINT_ACTION('Firing off map_cleaner', 0)
    t = threading.Thread(target=map_cleaner, args=[mapping, map_cleaner_queue])
    t.start()
    
    PRINT_ACTION('Creating and running UDP servers', 0)
    for port in ports:
        servers.append(UDPServer(SocketInstance(ip, port)))
        t = threading.Thread(target=servers[-1].run, args=[mapping, Qs, notify_queue, configs.get('timing')])
        t.start()
        threads.append(t)
    
    PRINT_ACTION('Creating and running the side channel', 0)
    side_channel = SideChannel(SocketInstance(ip, sidechannel_port))
    side_channel.run(notify_queue, map_cleaner_queue)
    
if __name__=="__main__":
    main()
    