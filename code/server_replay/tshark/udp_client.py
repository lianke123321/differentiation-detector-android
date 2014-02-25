'''
#######################################################################################################
#######################################################################################################

by: Arash Molavi Kakhki (arash@ccs.neu.edu)
    Northeastern University
    
Goal: client script for UDP replay

Usage:
    python udp_client.py

#######################################################################################################
#######################################################################################################
'''
import sys, socket, time, random, numpy, multiprocessing, threading, select, string
from python_lib import *

class Client(object):
    def __init__(self, dst_ip, dst_port, c_s_pair):
        self.c_s_pair = c_s_pair
        self.dst_ip   = dst_ip
        self.dst_port = dst_port
        self.sock, self.port = self.create_socket()
        self.NAT_port = None
    
    def create_socket(self):
        '''
        Creates UDP socket and force it to bind to a port by sending a dummpy packet
        '''
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.sendto('', ('127.0.0.1', 100))
        port = str(sock.getsockname()[1]).zfill(5)
        return sock, port
    
    def send_Q(self, Q, time_origin, timing):
        '''
        sends a queue of UDP packets to a socket server
        '''
        if timing:
            if time.time() < time_origin + Q.starttime:
                time.sleep((time_origin + Q.starttime) - time.time())

        for i in range(len(Q.Q)):
            udp_set = Q.Q[i]
            if timing:
                if time.time() < time_origin + udp_set.timestamp:
                    time.sleep((time_origin + udp_set.timestamp) - time.time())
            self.sock.sendto(udp_set.payload, (self.dst_ip, self.dst_port))
            print "sent:", udp_set.payload
        
    def receive(self):
        '''
        Keeps receiving on the socket. It will be terminated by the side channel 
        when a send done confirmation is received from the server.
        '''
        while True:
            data = self.sock.recv(4096)
            print '\tGot: ', data
    
    def identify(self, side_channel, NAT_map, id):
        '''
        Before anything, client needs to identify itself to the server and tell
        which c_s_pair it will be replaying.
        To do so, it sends the (id, c_s_pair) to server, waits for 1 second, and checks
        if side channel has received a confirmation. It keeps identifying until 
        acknowledgment is received from server.
        The ack contains clients external port (NAT port) which is stored for later use.
        '''
        while True:
            print '\tIdentifying:', self.port, '...',; sys.stdout.flush()
            message = ';'.join([id, self.c_s_pair])
            self.sock.sendto(message, (self.dst_ip, self.dst_port))
            r, w, e = select.select([side_channel.sock], [], [], 1)
            if r:
                NAT_port = r[0].recv(5)
                NAT_map[NAT_port] = self.port
                self.NAT_port = NAT_port
                print 'mapped to:', NAT_port
                break
    
    def close(self):
        self.sock.close()

class SideChannel(object):
    def __init__(self, instance, id):
        self.id       = id
        self.instance = instance
        self.sock     = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
        self.sock.connect((self.instance.ip, self.instance.port))
    
    def wait_for_fin(self, port_map, NAT_map):
        '''
        Keeps reading 5 bytes at a time (port numbers are 5 bytes)
        Everytime it receives a port number (note this is the NAT port), it means the 
        server is done sending packets to this port, and it removes it from the port_map. 
        Once port_map is empty, that means all receiving sockets can stop, so we
        break to close them.  
        '''
        while True:
            port = str(NAT_map[self.sock.recv(5)])
            port_map[port][0].close()
            port_map[port][1].terminate()
            del port_map[port]
            if len(port_map) == 0:
                break
    
    def ports_done_sending(self, clients):
        '''
        One replay is done, we send all NAT ports to server so it can clean up
        its mapping
        
        Format is NAT_port;NAT_port;...;FIN
        '''
        message = ';'.join([client.NAT_port for client in clients]) + ';FIN'
        self.send(message)
    
    def declare_id(self):
        self.send(self.id)
    
    def send(self, message):
        return self.sock.sendall(message)
        
    def terminate(self, clients):
        self.ports_done_sending(clients)
        self.sock.shutdown(socket.SHUT_RDWR)
        self.sock.close()

def id_generator(size=10, chars=string.ascii_letters + string.digits):
    return ''.join(random.choice(chars) for x in range(size))

def create_test_Qs():
    '''
    Making a test random Q
    
    Qs[c_s_pair] = UDPQueue
    
    UDPQueue --> Q, c_s_pair, starttime, dst_socket
                 Q = [UDPset]
                 UDPset --> payload, timestamp
    '''
    ports = [55055, 55056, 55057]
    Qs = []
    test_count = 5
    for i in range(len(ports)):
        c_s_pair = ''.join(['c_s_pair_' , str(i)])
        port = ports[i]
        timestamps = sorted([abs(numpy.random.normal(loc=1, scale=1, size=None)) for i in range(test_count+1)])
        
        queue = UDPQueue(starttime  = timestamps[0],
                         dst_socket = SocketInstance(Configs().get('instance').host, port),
                         c_s_pair   = c_s_pair.ljust(43))
        
        for j in range(test_count):
            payload   = ''.join([c_s_pair , '_' , str(j)])
            queue.Q.append(UDPset(payload, timestamps[j+1]))
        Qs.append(queue)
    
    for q in Qs:
        print q
    
    return Qs

def main():
    '''
    Communication sequence on side channel:
    
        1- Client creates side channel and connects to server
        2- Client sends its randomly generated ID (10 bytes) to server, side_channel.declare_id()
        3- Every client socket sends (id, c_s_pair) to corresponding socket server and receives
           acknowledgement on the side channel (this is repeated every 1 second until ack is 
           received), client.identify(side_channel, NAT_map, id)
           The acknowledgment/response from server is the client's port, so at this point client
           knows its NAT port
        4- Now client sockets start sending and receiving.
        5- Side channel listens for FIN confirmations from server sockets, and closes client socket 
           receiving processes
        6- Once all sending/receiving is done, the client sends all its NAT ports to server
           so it can clean up its maps
        7- Client closes the side channel.
    '''
    
    PRINT_ACTION('Reading configs file and args)', 0)
    configs = Configs()
    configs.set('original_ports', True)
    configs.set('timing', True)
    configs.set('instance', 'achtung')
    configs.read_args(sys.argv)
    configs.set('instance', Instance(configs.get('instance')))
    configs.show_all()

    PRINT_ACTION('Creating variables', 0)
    side_channel_port = 55555    
    id                = id_generator()
    clients           = []
    port_map          = {}
    NAT_map           = {}
    Qs                = create_test_Qs()
        
    PRINT_ACTION('Creating side channel and declaring client id', 0)
    side_channel = SideChannel(SocketInstance(configs.get('instance').host, side_channel_port), id)
    side_channel.declare_id()
    
    PRINT_ACTION('Creating all client sockets', 0)
    for i in range(len(Qs)):
        q = Qs[i]
        client = Client(configs.get('instance').host, q.dst_socket.port, q.c_s_pair)
        port_map[client.port] = [client]
        client.identify(side_channel, NAT_map, id)
        clients.append(client)
        
    PRINT_ACTION('Firing off all client sockets', 0)
    send_processes = []
    origin_time  = time.time()
    for i in range(len(Qs)):
        client = clients[i]
        p_send = multiprocessing.Process(target=client.send_Q, args=(Qs[i], origin_time, configs.get('timing')))
        p_recv = multiprocessing.Process(target=client.receive)
        port_map[client.port].append(p_recv)
        p_send.start()
        p_recv.start()
        send_processes.append(p_send)
    
    side_channel.wait_for_fin(port_map, NAT_map)
    
    for p in send_processes:
        p.join()
    
    side_channel.terminate(clients)

if __name__=="__main__":
    main()
    