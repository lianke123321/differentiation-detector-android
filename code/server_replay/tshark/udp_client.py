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

import sys, socket, time, random, numpy, multiprocessing, select, string, pickle, Queue, threading
from python_lib import *

DEBUG = 4

class Client(object):
    def __init__(self, dst_ip, id, replay_name):
        self.dst_ip       = dst_ip
        self.id           = id
        self.replay_name  = replay_name
        self.NAT_port     = {}
        self.identified   = {}
        self.sock         = None
        self.port         = None

    def create_socket(self):
        '''
        Creates UDP socket and force it to bind to a port by sending a dummy packet
        '''
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.sock.sendto('', ('127.0.0.1', 100))
        self.port = str(self.sock.getsockname()[1]).zfill(5)

    def identify(self, side_channel, q, c_s_pair, dst_port):
        '''
        Before anything, client needs to identify itself to the server and tell
        which c_s_pair and replay_name it will be replaying.
        To do so, it sends the id;c_s_pair;replay_name to server, waits for 1 second, and checks
        if side channel has received a confirmation. It keeps identifying until
        acknowledgment is received from server.
        The ack contains clients external port (NAT port) which is stored for later use.
        '''

        server_port = c_s_pair[-5:]
        message = ';'.join([self.id, server_port, self.replay_name])
        
        while True:
            if DEBUG == 2: print '\n\tIdentifying: {} -- {}...'.format(c_s_pair, server_port), 'to', (self.dst_ip, dst_port)
            self.sock.sendto(message, (self.dst_ip, dst_port))
            
            try:
                port = q.get(timeout=0.1)
            except Queue.Empty:
                continue
            
            self.NAT_port[server_port] = port
            self.identified[server_port] = None
            
            break
            
    def send_udp_packet(self, udp, dst_port):
        self.sock.sendto(udp.payload, (self.dst_ip, dst_port))
        if DEBUG == 2: print "sent:", udp.payload, 'TO:', udp.c_s_pair
        if DEBUG == 3: print "sent:", len(udp.payload), 'to', (self.dst_ip, dst_port)

    def receive(self):
        '''
        Keeps receiving on the socket. It will be terminated by the side channel
        when a send done confirmation is received from the server.
        '''
        while True:
            data = self.sock.recv(4096)
            if DEBUG == 2: print '\tGot: ', data
            if DEBUG == 3: print '\tGot: ', len(data), 'on', self.sock

    def terminate(self):
        self.sock.close()

class Receiver(object):
    def __init__(self, buff_size=4096):
        self.buff_size = buff_size
        
    def run(self, socket_list, close_q, server_ports_left):
        while server_ports_left > 0:
#             print 'server_ports_left:', server_ports_left
            r, w, e = select.select(socket_list, [], [], 0.1)
            for sock in r:
                data = sock.recv(self.buff_size)
                if DEBUG == 2: print '\tGot: ', data
                if DEBUG == 3: print '\tGot: ', len(data), 'on', sock
            try:
                while True:
                    NAT_port = close_q.get(False)
                    server_ports_left -= 1
            except Queue.Empty:
                pass
        PRINT_ACTION('Done receiving', 1, action=False)
        
class Sender(object):
    def __init__(self, udp_queue):
        self.Q = udp_queue

    def run(self, client_port_mapping, timing, side_channel, socket_list, notify_q, server_port_mapping):
        progress_bar = print_progress(len(self.Q))
        time_origin  = time.time()
        
        for udp in self.Q:
            if DEBUG == 4: progress_bar.next()

            client = client_port_mapping[udp.client_port]
            
            if client.sock is None:
                client.create_socket()
                socket_list.append(client.sock)
            
            dst_port = int(udp.c_s_pair[-5:])
            if server_port_mapping:
                dst_port = server_port_mapping[dst_port]
            
            server_port = udp.c_s_pair[-5:]
            if server_port not in client.identified:
                client.identify(side_channel, notify_q, udp.c_s_pair, dst_port)
                
            if timing:
                try:
                    time.sleep((time_origin + udp.timestamp) - time.time())
                except:
                    pass
            
            client.send_udp_packet(udp, dst_port)
            
        PRINT_ACTION('Done sending', 1, action=False)

class SideChannel(object):
    '''
    Steps:
        1- Initiate connection
        2- Identify --> send id;replay_name
        3- Receive server_port_mapping
        4- Receive acks (which is the NAT port) on Client identification
        5- Request and receive results
    '''
    def __init__(self, instance, buff_size=4096):
        self.buff_size = buff_size
        self.instance  = instance
        self.notify_q  = Queue.Queue()
        self.close_q   = Queue.Queue()
        self.sock      = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
        self.sock.connect((self.instance.ip, self.instance.port))

    def notifier(self, socket_list, server_ports_left):
        '''
        Listens for incoming objects:
            - NOTIFY: is acknowledging receipt of client socket identification
                      puts this on notify_q so the client.identify() knows
            - DONE:   id telling server is done sending with that port 
                      puts this on close_q so Receiver.run() gets it and stops when appropriate
        '''
        while server_ports_left > 0:
            r, w, e = select.select([self.sock], [], [])
            if r:
                data = self.receive_object().split(';')
                if data[0] == 'NOTIFY':
                    self.notify_q.put(data[1])
                elif data[0] == 'DONE':
                    server_ports_left -= 1
                    self.close_q.put(data[1])
            
    def receive_server_port_mapping(self):
        data = self.receive_object()
        if not data:
            return {}
        return pickle.loads(data)
    
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
    
    def get_result(self, id, outfile=None, result=False):
        if not result:
            self.send_object(';'.join(['NoResult', id]))
            return
        
        self.send_object(';'.join(['GiveMeResults', id]))
        result = self.receive_object()
        if outfile is not None:
            f = open(outfile, 'wb')
            f.write(result)
        return result
        
    def terminate(self, clients):
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
    ports = [55055, 55055, 55056]
    Q = []
    c_s_pairs = []
    test_count = 20
    timestamps = sorted([abs(numpy.random.normal(loc=1, scale=1, size=None)) for j in range(test_count)])

    for i in range(test_count):
        n        = random.randrange(len(ports))
        port     = ports[n]
        c_s_pair = 'XXX.XXX.XXX.XXX.10001-XXX.XXX.XXX.XX' + str(n) + '.' + str(port)
        if c_s_pair not in c_s_pairs:
            c_s_pairs.append(c_s_pair)
        Q.append(UDPset(str(i)+'-'+str(n), timestamps[i], c_s_pair, client_port=10001))
    
    for udp in Q:
        print udp
    
    return Q, [10001], len(set(ports)), c_s_pairs, 'test'

def load_Q(test, serialize='pickle'):
    '''
    This loads and de-serializes all necessary objects.
    
    NOTE: the parser encodes all packet payloads into hex before serializing them.
          So we need to decode them before starting the replay, hence the loop at
          the end of this function.
    '''
    if test:
        Q, client_ports, num_server_ports, c_s_pairs, replay_name = create_test_Q()
    
    else:
        for file in os.listdir(Configs().get('pcap_folder')):
            if file.endswith('_client_' + serialize):
                pickle_file = os.path.abspath(Configs().get('pcap_folder')) + '/' + file
                break

        if serialize == 'pickle':
            Q, client_ports, num_server_ports, c_s_pairs, replay_name = pickle.load(open(pickle_file, 'rb'))
        elif serialize == 'json':
            Q, client_ports, num_server_ports, c_s_pairs, replay_name= json.load(open(pickle_file, "r"), cls=UDPjsonDecoder_client)
    
    for udp in Q:
        udp.payload = udp.payload.decode('hex')
     
    return Q, client_ports, num_server_ports, c_s_pairs, replay_name
        
def run(*args):
    '''
    Communication sequence on side channel:

        1- Client creates side channel and connects to server
        2- Client sends its randomly generated ID (10 bytes) to server, side_channel.identify()
        3- Client receives port mapping from server, SideChannel().receive_server_port_mapping().
           This is necessary because server may choose no to use original ports.
        4- All client sockets are created
        5- Now client sockets start sending and receiving.
        6- Side channel listens for FIN confirmations from server sockets, SideChannel.notifier()
    '''

    PRINT_ACTION('Reading configs file and args)', 0)
    configs = Configs()
    configs.set('timing'  , True)
    configs.set('test'    , False)
    configs.set('result'  , False)
    configs.set('instance', 'achtung')
    configs.set('serialize', 'json')
    
    configs.read_args(sys.argv)
    configs.set('instance', Instance(configs.get('instance')))
    configs.show_all()

    PRINT_ACTION('Creating variables', 0)
    side_channel_port = 55555
    id                = id_generator()

    PRINT_ACTION('Loading the queue', 0)
    Q, client_ports, num_server_ports, c_s_pairs, replay_name = load_Q(configs.get('test'), serialize=configs.get('serialize'))
    
    PRINT_ACTION('Creating side channel and declaring client id', 0)
    side_channel = SideChannel(SocketInstance(configs.get('instance').host, side_channel_port))
    side_channel.identify(id, replay_name)
    server_port_mapping = side_channel.receive_server_port_mapping()
    
    PRINT_ACTION('Creating all client sockets', 0)
    client_port_mapping = {}
    socket_list      = []
    
    for client_port in client_ports:
        client = Client(configs.get('instance').host, id, replay_name)
        client_port_mapping[client_port] = client
    
    PRINT_ACTION('Running side channel notifier', 0)
    p_notf = threading.Thread( target=side_channel.notifier, args=(socket_list, num_server_ports,) )
    p_notf.start()
    
    PRINT_ACTION('Running the Receiver process', 0)
    p_recv = threading.Thread( target=Receiver().run, args=(socket_list, side_channel.close_q, num_server_ports,) )
    p_recv.start()
    
    PRINT_ACTION('Running the Sender process', 0)
    p_send = threading.Thread( target=Sender(Q).run, args=(client_port_mapping, configs.get('timing'), side_channel, socket_list, side_channel.notify_q, server_port_mapping, ) )
    p_send.start()

    p_send.join()
    p_recv.join()
    
    PRINT_ACTION('Receiving results ...', 0)
    side_channel.get_result(id, outfile='result.jpg', result=configs.get('result'))

    PRINT_ACTION('Fin', 0)

def main():
    run(sys.argv)

if __name__=="__main__":
    main()
