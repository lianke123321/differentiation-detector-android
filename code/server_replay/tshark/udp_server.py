'''
#######################################################################################################
#######################################################################################################

by: Arash Molavi Kakhki (arash@ccs.neu.edu)
    Northeastern University
    
Goal: this is a simple UDP server script for UDP testing

Usage:
    
ps aux | grep "python simple_udp_server.py" |  awk '{ print $2}' | xargs kill -9
#######################################################################################################
#######################################################################################################
'''
import sys, socket, threading, time, multiprocessing, numpy

from python_lib import *

class UDPServer(object):
    def __init__(self, instance):
        self.instance = instance
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.sock.bind((self.instance.ip, self.instance.port))
        print 'Created server at:', instance
    
    def wait_for_client(self):
        while True:
            print 'Waiting for client...({})'.format(str(self.instance))
            data, client_address = self.sock.recvfrom(1)
            print "New Client @{}: {}".format(self.instance.port, client_address)
    
    def receive(self):
        while True:
            data, client_address = self.sock.recvfrom(4096)
            print data, 'from', client_address, 'at', self.instance.port
            if data == 'CloseTheSocket':
                break
    
    def send_Q(self, Q, time_origin, event):
        self._wait_for_starttime(time_origin, Q.starttime)
        while Q.Q:
            udp_set = Q.Q.pop(0)
            if time.time() < time_origin + udp_set.timestamp:
                time.sleep((time_origin + udp_set.timestamp) - time.time())
            self.sock.sendto(udp_set.payload, (Q.destination.ip, Q.destination.port))
        self.sock.sendto('CloseTheSocket', (Q.destination.ip, Q.destination.port))
        self.terminate()
        event.set()
    
    def terminate(self):
        self.sock.close()

class SideChannel(object):
    def __init__(self, instance):
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
        self.sock.bind((instance.ip, instance.port))
        self.sock.listen(1)
        self.live = True
        
    def wait_for_client(self, mapping):
        while self.live:
            print 'Side channel waiting for clients...'
            connection, client_address = self.sock.accept()
            t = threading.Thread(target=self.handle_connection, args=[connection, client_address[0], mapping])
            t.start()
    
    def handle_connection(self, connection, client_ip, mapping):
        while True:
            data = connection.recv(3)
            if data == 'New':
                mapping[client_ip] = {}
                break
        while True:
            data = connection.recv(49)
            if data == 'Done':
                print 'got termination'
                break
            data = data.split(';')
            c_s_pair = data[0]
            port     = data[1]
            print 'got identification:', data
            mapping[client_ip][port] = c_s_pair
        print mapping
    
    def terminate(self):
        self.live = False
        self.sock.close()
        
def main():
    ip = '129.10.115.141'
    ports = [55055, 55056, 55057]
    sync_port = 55555
    
    Qs = {}
    mapping = {}
    
    test_count = 5
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
        Qs[c_s_pair] = queue
    
    for c_s_pair in Qs:
        print Qs[c_s_pair]
    
    side_channel = SideChannel(SocketInstance(ip, sync_port))
    
    processes = []
    threads   = []
    servers   = []
    
    for port in ports:
        servers.append(UDPServer(SocketInstance(ip, port)))
#        p = multiprocessing.Process(target=servers[-1].receive)
#        processes.append(p)
        t = threading.Thread(target=servers[-1].wait_for_client)
        t.start()
        threads.append(t)
    
    PRINT_ACTION('Side channel waiting for clients...', 0)
    side_channel.wait_for_client(mapping)
    
#    for t in threads:
#        t.start()
    
#    for p in processes:
#        p.start()
    
    PRINT_ACTION('Waiting for termination signal...', 0)
    side_channel.wait_for_identification(mapping)
    print mapping
if __name__=="__main__":
    main()
    