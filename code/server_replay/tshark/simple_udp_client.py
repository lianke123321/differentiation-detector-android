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
import sys, socket, time, random, numpy, threading
from python_lib import *
from vpn_no_vpn import tcpdump

def client(instance, message):
    print "Sending:", message
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.sendto(message, (instance.ip, instance.port))

class Client(object):
    def __init__(self):
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    
    def send_Q(self, Q, time_origin, event):
        self._wait_for_starttime(time_origin, Q.starttime)
        while Q.Q:
            udp_set = Q.Q.pop(0)
            if time.time() < time_origin + udp_set.timestamp:
                time.sleep((time_origin + udp_set.timestamp) - time.time())
            self.sock.sendto(udp_set.payload, (Q.destination.ip, Q.destination.port))
        self.sock.sendto('CloseTheSocket', (Q.destination.ip, Q.destination.port))
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
    Qs = []
    
    
    '''
    ###########################################################################
    Making a test random Q
    self.connection = 
    '''
    for i in range(len(ports)):
        c_s_pair = ''.join(['c_s_pair_' , str(i)])
        port = ports[i]
        queue = UDPQueue(starttime   = abs(numpy.random.normal(loc=1, scale=1, size=None)),
                         destination = SocketInstance(ip, port, c_s_pair),
                         c_s_pair    = c_s_pair)
        for j in range(5):
            timestamp = abs(numpy.random.normal(loc=1, scale=1, size=None))
            payload   = ''.join([c_s_pair , '_' , str(j)]) 
            queue.Q.append(UDPset(payload, timestamp))
        Qs.append(queue)
    
    for q in Qs:
        print q

    
    side_channel = SideChannel(SocketInstance(ip, sync_port, 'SideChannel'))
    origin_time = time.time()
    side_channel.sync()
    
    event = threading.Event()
    
    clients = []
    for q in Qs:
        clients.append(Client())
        t = threading.Thread(target=clients[-1].send_Q, args=[q, origin_time, event])
        t.start()
    
    while True:
        if threading.activeCount() == 1:
            break
        event.clear()
        event.wait()
    
    side_channel.terminate()
    
if __name__=="__main__":
    main()
    