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

class UDPServer(object):
    def __init__(self, instance):
        self.instance = instance
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.sock.bind((self.instance.ip, self.instance.port))
        print 'Created server at:', instance
            
    def wait_for_client(self, mapping, Qs, queue):
        while True:
            data, client_address = self.sock.recvfrom(4096)
            print "{} from {} @ {}".format(data, client_address, self.instance.port)
            
            client_ip   = client_address[0]
            client_port = client_address[1]
            
            if client_ip not in mapping:
                print 'NEW IP:', client_ip
                mapping[client_ip] = {}
            
            try:
                c_s_pair = mapping[client_ip][client_port]
                if c_s_pair is None:
                    pass
                mapping[client_ip][client_port] = None
                p = multiprocessing.Process(target=self.send_Q(Qs[c_s_pair], time.time(), client_address, queue))
                p.start()
            except KeyError:
                print 'New port:', client_address
                mapping[client_ip][client_port] = data
                queue.put(client_address)
                print  queue.qsize()
                        
    def receive(self):
        while True:
            data, client_address = self.sock.recvfrom(4096)
            print data, 'from', client_address, 'at', self.instance.port
            if data == 'CloseTheSocket':
                break
    
    def send_Q(self, Q, time_origin, client_address, queue):
        if time.time() < time_origin + Q.starttime:
            time.sleep((time_origin + Q.starttime) - time.time())
        
        for i in range(len(Q.Q)):
            udp_set = Q.Q[i]
            if time.time() < time_origin + udp_set.timestamp:
                time.sleep((time_origin + udp_set.timestamp) - time.time())
            self.sock.sendto(udp_set.payload, client_address)
            print '\tSent', udp_set.payload, 'to', client_address
        
        print '\n\nDONE WITH:', client_address, '\n\n'
        queue.put(client_address)
        
    def terminate(self):
        self.sock.close()

class SideChannel(object):
    def __init__(self, instance):
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
        self.sock.bind((instance.ip, instance.port))
        self.sock.listen(1)
        self.connection_map = {}
        self.queue = None
    
    def run(self, queue):
        t1 = threading.Thread(target=self.wait_for_connections)
        t2 = threading.Thread(target=self.notify, args=(queue,))
        t1.start()
        t2.start()
    
    def notify(self, queue):
        while True:
            print 'Waiting to read from queue...'
            data      = queue.get()
            client_ip = data[0]
            port      = data[1]
            print 'Sending', port, 'TO', client_ip
            self.connection_map[client_ip].sendall(str(port))
            
    def wait_for_connections(self):
        while True:
            connection, client_address = self.sock.accept()
            self.connection_map[client_address[0]] = connection
            
    def terminate(self):
        self.live = False
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
    ip = '127.0.0.1'
    ip = '129.10.115.141'
    ip = ''
    sidechannel_port = 55555
    
    Qs, ports = create_test_Qs(ip)
    
    '''
    ###########################################################################
    mapping: mapping[client_ip][port] = c_s_pair
             Gets populated in SideChannel.handle_connection()
             Every time a connection comes in, mapping[client_ip] is set to {},
             then the client keeps identifying what port is for what c_s_pair
    ########################################################################### 
    '''    
    PRINT_ACTION('Creating servers', 0)
    threads = []
    servers = []
    mapping = {}
    queue   = multiprocessing.Queue()
    
    for port in ports:
        servers.append(UDPServer(SocketInstance(ip, port)))
        t = threading.Thread(target=servers[-1].wait_for_client, args=[mapping, Qs, queue])
        t.start()
        threads.append(t)
    
    PRINT_ACTION('Creating side-channel', 0)
    
    side_channel = SideChannel(SocketInstance(ip, sidechannel_port))
    side_channel.run(queue)
    
if __name__=="__main__":
    main()
    