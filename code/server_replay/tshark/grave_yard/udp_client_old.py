'''
#######################################################################################################
#######################################################################################################

by: Arash Molavi Kakhki (arash@ccs.neu.edu)
    Northeastern University

Goal: client script for UDP replay

Usage:
    python udp_client.py --pcap_folder=[]
Example:
    python udp_client.py --pcap_folder=../data/skype_cut_off_10/

#######################################################################################################
#######################################################################################################
'''

import sys, socket, time, random, numpy, multiprocessing, threading, select, string, pickle
from python_lib import *

DEBUG = 2

class Client(object):
    def __init__(self, dst_ip, dst_port, c_s_pair):
        self.c_s_pair = c_s_pair
        self.dst_ip   = dst_ip
        self.dst_port = dst_port
        self.sock, self.port = self._create_socket()
        self.NAT_port = None

    def _create_socket(self):
        '''
        Creates UDP socket and force it to bind to a port by sending a dummpy packet
        '''
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.sendto('', ('127.0.0.1', 100))
        port = str(sock.getsockname()[1]).zfill(5)
        return sock, port

    def identify(self, side_channel, NAT_map, id, replay_name):
        '''
        Before anything, client needs to identify itself to the server and tell
        which c_s_pair it will be replaying.
        To do so, it sends the (id, c_s_pair) to server, waits for 1 second, and checks
        if side channel has received a confirmation. It keeps identifying until
        acknowledgment is received from server.
        The ack contains clients external port (NAT port) which is stored for later use.
        '''
        while True:
            print '\tIdentifying: {}--{} for {} to {} ...'.format(id, self.port, self.c_s_pair, (self.dst_ip, self.dst_port)),; sys.stdout.flush()
            message = ';'.join([id, self.c_s_pair, replay_name])
            self.sock.sendto(message, (self.dst_ip, self.dst_port))
            r, w, e = select.select([side_channel.sock], [], [], 1)
            if r:
                NAT_port = r[0].recv(5)
                NAT_map[NAT_port] = self.port
                self.NAT_port = NAT_port
                print 'mapped to:', NAT_port
                break

    def send_udp_packet(self, udp_payload):
        self.sock.sendto(udp_payload, (self.dst_ip, self.dst_port))
        if DEBUG == 2: print "sent:", udp_payload
        if DEBUG == 3: print "sent:", len(udp_payload), 'to', (self.dst_ip, self.dst_port)

    def receive(self):
        '''
        Keeps receiving on the socket. It will be terminated by the side channel
        when a send done confirmation is received from the server.
        '''
        while True:
            data = self.sock.recv(4096)
            if DEBUG == 2: print '\tGot: ', data
            if DEBUG == 3: print '\tGot: ', len(data), 'on', self.sock

    def close(self):
        self.sock.close()

class Queue(object):
    def __init__(self, udp_queue):
        self.Q = udp_queue

    def run(self, c_s_pair_mapping, timing):
        progress_bar = print_progress(len(self.Q))
        time_origin = time.time()
        for udp in self.Q:
            if DEBUG == 4: progress_bar.next()
            if timing:
                if time.time() < time_origin + udp.timestamp:
                    try:
                        time.sleep((time_origin + udp.timestamp) - time.time())
                    except:
                        pass

            c_s_pair_mapping[udp.c_s_pair].send_udp_packet(udp.payload)

class SideChannel(object):
    def __init__(self, instance, buff_size=4096):
        self.buff_size = buff_size
        self.instance  = instance
        self.sock      = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
        self.sock.connect((self.instance.ip, self.instance.port))

    def wait_for_fin(self, port_map, NAT_map):
        '''
        Keeps reading 5 bytes at a time (port numbers are 5 bytes)
        Every time it receives a port number (note this is the NAT port), it means the
        server is done sending packets to this port, and it removes it from the port_map.
        Once port_map is empty, that means all receiving sockets can stop, so we
        break to close them.

        port_map[client.port] = (client, p_recv)
        '''
        count = 0
        while True:
            port = str(NAT_map[self.sock.recv(5)])
            port_map[port][1].terminate()
            count += 1
            if count == len(port_map):
                break

    def receive_server_port_mapping(self):
        data = self.receive_object()
        if not data:
            return {}
        return pickle.loads(data)
    
    def ports_done_sending(self, clients):
        '''
        Once replay is done, we send all NAT ports to server so it can clean up
        its mapping
        '''
        message = ';'.join([client.NAT_port for client in clients])
        self.send_object(message)

    def identify(self, id, replay_name):
        self.send_object(';'.join([id, replay_name]))
     
    def send_object(self, message, obj_size_len=10):
        self.sock.sendall(str(len(message)).zfill(obj_size_len))
        self.sock.sendall(message)
        
    def receive_object(self, obj_size_len=10):
        object_size = int(self.receive_b_bytes(obj_size_len))
        return self.receive_b_bytes(object_size)
    
    def receive_b_bytes(self, b):
        data = ''
        while len(data) < b:
            data += self.sock.recv( min(b-len(data), self.buff_size) )
        return data
        
    def terminate(self, clients):
        self.ports_done_sending(clients)
        for client in clients:
            client.close()
        self.sock.shutdown(socket.SHUT_RDWR)
        self.sock.close()

def id_generator(size=10, chars=string.ascii_letters + string.digits):
    return ''.join(random.choice(chars) for x in range(size))

def create_test_Q():
    '''
    Making a test random Q

    Q = [UDPset, UDPset, ...]

        UDPset --> payload, timestamp, c_s_pair
    '''
    ports = [55055, 55055]
    Q = []
    c_s_pairs = []
    test_count = 20
    timestamps = sorted([abs(numpy.random.normal(loc=1, scale=1, size=None)) for j in range(test_count)])

    for i in range(test_count):
        n        = random.randrange(len(ports))
        port     = ports[n]
        c_s_pair = str(n) + 'XX.XXX.XXX.XXX.XXXXX-XXX.XXX.XXX.XXX.' + str(port)

        Q.append(UDPset(str(i)+'-'+str(n), timestamps[i], c_s_pair))

        if c_s_pair not in c_s_pairs:
            c_s_pairs.append(c_s_pair)

    return Q, c_s_pairs, 'test'

def load_Q(test):
    '''
    Loads the Q from pickle dump or creates a new randomly generated Q if test == True
    '''
    if test:
        Q, c_s_pairs, replay_name = create_test_Q()
    
    else:
        for file in os.listdir(Configs().get('pcap_folder')):
            if file.endswith('_client_pickle'):
                pickle_file = os.path.abspath(Configs().get('pcap_folder')) + '/' + file
                break
        Q, c_s_pairs, replay_name = pickle.load(open(pickle_file, 'rb'))
    
    return Q, c_s_pairs, replay_name

def main():
    '''
    Communication sequence on side channel:

        1- Client creates side channel and connects to server
        2- Client sends its randomly generated ID (10 bytes) to server, side_channel.identify()
        3- Client receives port mapping from server, SideChannel().receive_server_port_mapping().
           This is necessary because server may choose no to use original ports.
        4- Every client socket sends (id, c_s_pair) to corresponding socket server and receives
           acknowledgement on the side channel (this is repeated every 1 second until ack is
           received), client.identify(side_channel, NAT_map, id)
           The acknowledgment/response from server is the client's port, so at this point client
           knows its NAT port
        5- Now client sockets start sending and receiving.
        6- Side channel listens for FIN confirmations from server sockets, and closes client socket
           receiving processes
        7- Once all sending/receiving is done, the client sends all its NAT ports to server
           so it can clean up its maps
        8- Client closes the side channel.
    '''

    PRINT_ACTION('Reading configs file and args)', 0)
    configs = Configs()
    configs.set('timing', True)
    configs.set('test', False)
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

    PRINT_ACTION('Loading the queue', 0)
    Q, c_s_pairs, replay_name = load_Q(configs.get('test'))

    PRINT_ACTION('Creating side channel and declaring client id', 0)
    side_channel = SideChannel(SocketInstance(configs.get('instance').host, side_channel_port))
    side_channel.identify(id, replay_name)
    server_port_maps = side_channel.receive_server_port_mapping()

    PRINT_ACTION('Creating all client sockets', 0)
    c_s_pair_mapping = {}

    for c_s_pair in c_s_pairs:
        dst_port = int(c_s_pair[-5:])
        if server_port_maps:
            dst_port = server_port_maps[dst_port]
        client = Client(configs.get('instance').host, dst_port, c_s_pair)
        client.identify(side_channel, NAT_map, id, replay_name)
        p_recv = multiprocessing.Process(target=client.receive)
        p_recv.start()
        port_map[client.port] = (client, p_recv)
        c_s_pair_mapping[c_s_pair] = client
        clients.append(client)

    send_proccess = multiprocessing.Process(target=Queue(Q).run, args=(c_s_pair_mapping, configs.get('timing'),))
    send_proccess.start()

    side_channel.wait_for_fin(port_map, NAT_map)
    send_proccess.join()
    side_channel.terminate(clients)

if __name__=="__main__":
    main()

