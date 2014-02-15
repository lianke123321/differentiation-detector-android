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
from python_lib import Configs, PRINT_ACTION, UDPset
from vpn_no_vpn import tcpdump

def client(instance, message):
    print "Sending:", message
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.sendto(message, (instance.ip, instance.port))

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
    sync_port = 55555
    
    instances = []
    Q = {}
    for port in ports:
        instances.append(ServerInstance(ip, port, c_s_pair))
        
#        for i in range(5):
#            delay = abs(numpy.random.normal(loc=0.01, scale=0.1, size=None))
#            UDPset()
    
#    dump = tcpdump(dump_name='kir')
#    dump.start()
#    time.sleep(2)

    side_channel = SideChannel(ServerInstance(ip, sync_port))
    print side_channel.sync()
    
    
    for i in range(5):
        client( instances[random.randrange(3)], 'c-'+str(i) )
        delay = abs(numpy.random.normal(loc=0.01, scale=0.1, size=None))
        time.sleep(delay)
    
    client(instances[0], 'CloseTheSocket')
    client(instances[1], 'CloseTheSocket')
    client(instances[2], 'CloseTheSocket')
    
    side_channel.terminate()
    
#    dump.stop()
    
if __name__=="__main__":
    main()
    