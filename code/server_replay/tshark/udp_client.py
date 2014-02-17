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

class Client(object):
    def __init__(self, dst_ip, dst_port, c_s_pair):
        self.dst_ip   = dst_ip
        self.dst_port = dst_port
        self.c_s_pair = c_s_pair
        self.sock     = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        '''This is to force the socket to bind to a port'''
        self.sock.sendto('', ('127.0.0.1', 100))
        self.port = str(self.sock.getsockname()[1]).zfill(5)
        
    def send_Q(self, Q, time_origin, side_channel):
        if time.time() < time_origin + Q.starttime:
            time.sleep((time_origin + Q.starttime) - time.time())

        for i in range(len(Q.Q)):
            udp_set = Q.Q[i]
            if time.time() < time_origin + udp_set.timestamp:
                time.sleep((time_origin + udp_set.timestamp) - time.time())
            self.sock.sendto(udp_set.payload, (self.dst_ip, self.dst_port))
            print "sent:", udp_set.payload
        
        self.sock.sendto('CloseTheSocket', (self.dst_ip, self.dst_port))
        self.close()
    
    def receive(self):
        while True:
            data = self.sock.recv(4096)
            print '\tGot: ', data
    
    def close(self):
        self.sock.close()

class SideChannel(object):
    def __init__(self, instance):
        self.instance = instance
        self.sock     = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
        self.sock.connect((self.instance.ip, self.instance.port))
    
    def identify_client(self, client):
        message = ';'.join([client.c_s_pair, client.port])
        print message, len(message)
        self.send(message)
    
    def send(self, message):
        return self.sock.sendall(message)
        
    def sync(self):
        return self.send('Sync')
    
    def wait_for_fin(self, event, port_map):
        while True:
            port = self.sock.recv(5)
            port_map[port][0].close()
            port_map[port][1].terminate()
            del port_map[port]
            if len(port_map) == 0:
                break
    
    def terminate(self):
        self.send('Done')
        self.sock.shutdown(socket.SHUT_RDWR)
        self.sock.close()

def main():
#    ip = '129.10.115.141'
    ip = '127.0.0.1'
    ports = [55055, 55056, 55057]
    side_channel_port = 55555
    
    instances = {}
    
    '''
    ###########################################################################
    Making a test random Q
    
    Qs[c_s_pair] = UDPQueue
    
    UDPQueue --> Q, c_s_pair, starttime, dst_socket
                 Q = [UDPset]
                 UDPset --> payload, timestamp
    ########################################################################### 
    '''
    Qs = []
    test_count = 5
    for i in range(len(ports)):
        c_s_pair = ''.join(['c_s_pair_' , str(i)])
        port = ports[i]
        timestamps = sorted([abs(numpy.random.normal(loc=1, scale=1, size=None)) for i in range(test_count+1)])
        
        queue = UDPQueue(starttime  = timestamps[0],
                         dst_socket = SocketInstance(ip, port),
                         c_s_pair   = c_s_pair.ljust(43))
        
        for j in range(test_count):
            payload   = ''.join([c_s_pair , '_' , str(j)])
            queue.Q.append(UDPset(payload, timestamps[j+1]))
        Qs.append(queue)
    
    for q in Qs:
        print q
    '''
    ###########################################################################
    '''
    PRINT_ACTION('Opening side-channel', 0)
    side_channel = SideChannel(SocketInstance(ip, side_channel_port))
    side_channel.send('New')
    
    clients   = []
    port_map  = {}
    
    PRINT_ACTION('Creating all client sockets', 0)
    for i in range(len(Qs)):
        q = Qs[i]
        client = Client(q.dst_socket.ip, q.dst_socket.port, q.c_s_pair)
        side_channel.identify_client(client)
        port_map[client.port] = [client]
        clients.append(client)
    side_channel.send('Done')
    time.sleep(2)
    
    PRINT_ACTION('Firing off all client sockets', 0)
    origin_time  = time.time()
    for i in range(len(Qs)):
        client = clients[i]
        p_send = multiprocessing.Process(target=client.send_Q, args=(Qs[i], origin_time, side_channel))
        p_recv = multiprocessing.Process(target=client.receive)
        port_map[client.port].append(p_recv)
        p_send.start()
        p_recv.start()
    
    event = multiprocessing.Event()
    side_channel.wait_for_fin(event, port_map)
    side_channel.terminate()

if __name__=="__main__":
    main()
    