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
import sys, socket, time, random, numpy
from python_lib import Configs, PRINT_ACTION, UDPset, ServerInstance
from vpn_no_vpn import tcpdump

def client(instance, message):
    print "Sending:", message
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.sendto(message, (instance.ip, instance.port))

class Client(object):
    def __init__(self):
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    
    def send_Q(self, Q, destination_instance, time_origin):
        _wait_for_starttime(self, time_origin, Q.starttime)
        while Q:
            udp_set = Q.pop(0)
            if time.time() < time_origin + udp_set.timestamp:
                time.sleep((time_origin + udp_set.timestamp) - time.time())
            sock.sendto(udp_set.payload, (destination_instance.ip, destination_instance.port))
        self.close()
        
    def _wait_for_starttime(self, time_origin, starttime):
        if time.time() < time_origin + starttime:
            time.sleep((time_origin + starttime) - time.time())
    
    def close(self):
        self.sock.close()

class SideChannel(object):
    def __init__(self, instance):
        self.ip   = instance.ip
        self.port = instance.port
        self.sock = None
        
    def _connect(self):
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
        self.sock.connect((self.ip, self.port))
    
    def sync(self):
        self._connect()
        return self.sock.sendall('Sync')
    
    def terminate(self):
        self._connect()
        return self.sock.sendall('Terminate')

def main():
    ip = '129.10.115.141'
    ports = [55055, 55056, 55057]
    sync_port = 55556
    
    instances = {}
    Q = {}
    
    for i in range(len(ports)):
        c_s_pair = ''.join(['c_s_pair_' , str(i)])
        port = ports[i]
        instances[c_s_pair] = ServerInstance(ip, port, c_s_pair)
        Q[c_s_pair] = []
        for j in range(5):
            timestamp = abs(numpy.random.normal(loc=0.01, scale=0.1, size=None))
            payload   = ''.join([c_s_pair , '_' , str(j)]) 
            Q[c_s_pair].append(UDPset(payload, timestamp))
    
    for c_s_pair in Q:
        print c_s_pair
        for pl in Q[c_s_pair]:
            print '\t{}'.format(pl)

    side_channel = SideChannel(ServerInstance(ip, sync_port, 'SideChannel'))
    print side_channel.sync()    
    
    
    
    for i in range(5):
        client( instances[random.randrange(3)], 'c-'+str(i) )
        delay = abs(numpy.random.normal(loc=0.01, scale=0.1, size=None))
        time.sleep(delay)
    
    client(instances[0], 'CloseTheSocket')
    client(instances[1], 'CloseTheSocket')
    client(instances[2], 'CloseTheSocket')
    
    side_channel.terminate()
    
if __name__=="__main__":
    main()
    