'''
#######################################################################################################
#######################################################################################################

by: Arash Molavi Kakhki (arash@ccs.neu.edu)
    Northeastern University
    
Goal: this is a simple UDP client script for UDP testing

Usage:
    

#######################################################################################################
#######################################################################################################
'''
import sys, socket, time, random, numpy, threading, multiprocessing
from python_lib import *
from vpn_no_vpn import tcpdump

def client(instance, message):
    print "Sending:", message
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.sendto(message, (instance.ip, instance.port))

class Client(object):
    def __init__(self, dst_ip, dst_port, c_s_pair):
        self.sock     = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.dst_ip   = dst_ip
        self.dst_port = dst_port
        self.c_s_pair = c_s_pair
        
    def send_Q(self, Q, time_origin, event):
        self._wait_for_starttime(time_origin, Q.starttime)
        for i in range(len(Q.Q)):
            udp_set = Q.Q[i]
            if time.time() < time_origin + udp_set.timestamp:
                time.sleep((time_origin + udp_set.timestamp) - time.time())
            self.sock.sendto(udp_set.payload, (self.dst_ip, self.dst_port))
        self.sock.sendto('CloseTheSocket', (self.dst_ip, self.dst_port))
        self.close()
        event.set()
        
    def _wait_for_starttime(self, time_origin, starttime):
        if time.time() < time_origin + starttime:
            time.sleep((time_origin + starttime) - time.time())
    
    def close(self):
        self.sock.close()

class SideChannel(object):
    def __init__(self, instance):
        self.instance = instance
        self.sock     = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
        self.sock.connect((self.instance.ip, self.instance.port))
    
    def sync(self):
        return self.sock.sendall('Sync')
    
    def terminate(self):
        self.sock.sendall('Terminate')
        self.sock.shutdown(socket.SHUT_RDWR)
        self.sock.close()

def main():
    ip = '129.10.115.141'
    ports = [55055, 55056, 55057]
    sync_port = 55555
    
    instances = {}
    Qs = {}
    
    '''
    ###########################################################################
    Making a test random Q
    ########################################################################### 
    '''
    test_count = 5
    for i in range(len(ports)):
        c_s_pair = ''.join(['c_s_pair_' , str(i)])
        port = ports[i]
        timestamps = sorted([abs(numpy.random.normal(loc=1, scale=1, size=None)) for i in range(test_count+1)])
        
        queue = UDPQueue(starttime  = timestamps[0],
                         dst_socket = SocketInstance(ip, port, c_s_pair),
                         c_s_pair   = c_s_pair)
        
        for j in range(test_count):
            payload   = ''.join([c_s_pair , '_' , str(j)])
            queue.Q.append(UDPset(payload, timestamps[j+1]))
        Qs[c_s_pair] = queue
    
    for c_s_pair in Qs:
        print Qs[c_s_pair]

    
    side_channel = SideChannel(SocketInstance(ip, sync_port, 'SideChannel'))
    origin_time = time.time()
    side_channel.sync()
    
    event = multiprocessing.Event()
    
    clients   = []
    processes = []
    for c_s_pair in Qs:
        q = Qs[c_s_pair]
        clients.append(Client(q.dst_socket.ip, q.dst_socket.port, q.c_s_pair))
        p = multiprocessing.Process(target=clients[-1].send_Q, args=(q, origin_time, event))
        processes.append(p)
        
    for p in processes:
        p.start()
    
    while True:
        if len(multiprocessing.active_children()) == 1:
            break
        event.clear()
        event.wait()
    
    side_channel.terminate()
    
if __name__=="__main__":
    main()
    