'''
#######################################################################################################
#######################################################################################################

by: Arash Molavi Kakhki (arash@ccs.neu.edu)
    Northeastern University
    
Goal: this is a simple UDP server script for UDP testing

Usage:
    
ps aux | grep "python udp_server.py" |  awk '{ print $2}' | xargs kill -9
#######################################################################################################
#######################################################################################################
'''
import sys, socket, threading, time, multiprocessing, numpy, select

from python_lib import *

DEBUG = 2

class UDPServer(object):
    def __init__(self, instance):
        self.instance = instance
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.sock.bind((self.instance.ip, self.instance.port))
        print 'Created server at:', instance
            
    def run(self, mapping, Qs, queue):
        '''
        Receives UDP packets.
        
        Every time a packet comes in:
            - If the IP is not in mapping --> it's a new client, add it to mapping
            - mapping[client_ip][client_port] doesn't exist --> New port, add it to mapping 
              and put on the queue to acknowledge the client
            - if mapping[client_ip][client_port] == None --> Already started sending packets to this
              client:port
            - else fire off send_Q to send packets to this client:port
            
        mapping[client_ip][client_port] = c_s_pair (or None if already taken care of)
        '''
        while True:
            data, client_address = self.sock.recvfrom(4096)
            
            client_ip   = client_address[0]
            client_port = client_address[1]
            
            if client_ip not in mapping:
                mapping[client_ip] = {}
            
            try:
                (id, c_s_pair) = mapping[client_ip][client_port]
                if c_s_pair is None:
                    continue
                mapping[client_ip][client_port] = (None, None)
                p = multiprocessing.Process(target=self.send_Q(Qs[c_s_pair], time.time(), client_address, queue, id))
                p.start()
            
            except KeyError:
                if DEBUG == 1: print 'New port:', client_address, data
                data     = data.split(';')
                id       = data[0]
                c_s_pair = data[1]
                mapping[client_ip][client_port] = (id, c_s_pair)
                queue.put((id, client_port))
                
                if DEBUG == 2:
                    print 'mapping'
                    for ip in mapping:
                        print '\t', ip
                        for port in mapping[ip]:
                            print '\t\t', port, '\t', mapping[ip][port]
                
                        
    def send_Q(self, Q, time_origin, client_address, queue, id):
        '''
        sends a queue of UDP packets, i.e. Q to client_address
        Once done, put on queue to notify client
        '''
        if time.time() < time_origin + Q.starttime:
            time.sleep((time_origin + Q.starttime) - time.time())
        
        for i in range(len(Q.Q)):
            udp_set = Q.Q[i]
            if time.time() < time_origin + udp_set.timestamp:
                time.sleep((time_origin + udp_set.timestamp) - time.time())
            self.sock.sendto(udp_set.payload, client_address)
        
        queue.put((id, client_address[1]))
        
    def terminate(self):
        self.sock.close()

class SideChannel(object):
    def __init__(self, instance):
        self.connection_map  = {}
        self.connection_list = []
        self.sock = self.create_socket(instance)
    
    def create_socket(self, instance):
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
        sock.bind((instance.ip, instance.port))
        sock.listen(1)
        return sock
    
    def run(self, queue):
        '''
        SideChannel has two main method that should be always running
        
            1- wait_for_connections: every time a new connection comes in, it stores/updates
               connection_map for future conversations with the client
            2- notify: constantly gets jobs from a queue and notifies clients.
               This could be acknowledgment of new port or notifying of a send_Q end so
               the client can stop the receiving thread on the socket.
        '''
        
        t1 = threading.Thread(target=self.wait_for_connections)
        t2 = threading.Thread(target=self.notify, args=(queue,))        
        map(lambda t: t.start(), [t1, t2])
        
    def notify(self, queue):
        while True:
            data = queue.get()
            id   = data[0]
            port = data[1]
            if DEBUG==1: print '\tNOTIFYING:', data, str(port).zfill(5)
            self.connection_map[id].sendall(str(port).zfill(5))
            
    def wait_for_connections(self):
        while True:
            connection, client_address = self.sock.accept()
            t = threading.Thread(target=self.handle_connection, args=(connection,))
            t.start()
    
    def handle_connection(self, connection):
        id = connection.recv(10)
        self.connection_map[id] = connection
        self.connection_list.append(connection)
#        print 'self.connection_map:'
#        for id in self.connection_map:
#            print '\t', id, self.connection_map[id]
        id = connection.recv(10)
        del self.connection_map[id]
    
    def terminate(self):
        self.sock.close()

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
        c_s_pair = ''.join(['c_s_pair_' , str(i)])
        port = ports[i]
        timestamps = sorted([abs(numpy.random.normal(loc=1, scale=1, size=None)) for i in range(test_count+1)])
        
        queue = UDPQueue(starttime  = timestamps[0],
                         dst_socket = None,
                         c_s_pair   = c_s_pair)
        
        for j in range(test_count):
            payload   = ''.join([c_s_pair , '_' , str(j)])
            queue.Q.append(UDPset(payload, timestamps[j+1]))
        Qs[c_s_pair.ljust(43)] = queue
    
    for c_s_pair in Qs:
        print Qs[c_s_pair]
    
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
    PRINT_ACTION('Creating servers for all ports', 0)
    threads = []
    servers = []
    mapping = {}
    queue   = multiprocessing.Queue()
    
    for port in ports:
        servers.append(UDPServer(SocketInstance(ip, port)))
        t = threading.Thread(target=servers[-1].run, args=[mapping, Qs, queue])
        t.start()
        threads.append(t)
    
    PRINT_ACTION('Creating and running the side channel', 0)
    side_channel = SideChannel(SocketInstance(ip, sidechannel_port))
    side_channel.run(queue)
    
if __name__=="__main__":
    main()
    