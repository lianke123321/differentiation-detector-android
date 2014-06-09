'''
#######################################################################################################
#######################################################################################################

by: Arash Molavi Kakhki (arash@ccs.neu.edu)
    Northeastern University

Goal: client script for TCP replay

Usage:
    python tcp_client.py --pcap_folder=[]
Example:
    python tcp_client.py --pcap_folder=../data/dropbox_d

#######################################################################################################
#######################################################################################################
'''

import sys, socket, time, random, numpy, threading, select, string, pickle
from python_lib import *

DEBUG = 4

class Client(object):
    def __init__(self, dst_ip, dst_port, c_s_pair, replay_name, id, buff_size=4096):
        self.replay_name = replay_name
        self.c_s_pair    = c_s_pair
        self.id          = id
        self.dst_ip      = dst_ip
        self.dst_port    = dst_port
        self.sock        = None
        self.buff_size   = buff_size
        self.event       = threading.Event()
        self.event.set()    #This is necessary so all clients are initially marked as ready

    def _connect_socket(self):
        '''
        Steps:
            1- Create and connect TCP socket
            2- Identifies itself --> tells server what's replaying (replay_name and c_s_pair)
        '''
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
        self.sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.sock.connect((self.dst_ip, self.dst_port))
        self._identify()

    def _identify(self):
        '''
        Before anything, client needs to identify itself to the server and tell
        which c_s_pair it will be replaying.
        '''
        message = ';'.join([self.id, self.c_s_pair, self.replay_name])
        self.send_object(message)
    
    def send_object(self, message, obj_size_len=10):
        self.sock.sendall(str(len(message)).zfill(obj_size_len))
        self.sock.sendall(message)
    
    def single_tcp_request_response(self, tcp, send_event):
        '''
        Steps:
            1- Send out the payload
            2- Set send_event to notify you are done sending
            3- Receive response (if any)
            4- Set self.event to notify you are done receiving
        '''
        if self.sock is None:
            self._connect_socket()
        
        self.sock.sendall(tcp.payload)
        send_event.set()
        
        if DEBUG == 2: print "sent:", tcp.payload, 'for', self.c_s_pair
        if DEBUG == 3: print "sent:", len(tcp.payload), 'for', self.c_s_pair
        
        buffer_len = 0
        while tcp.response_len > buffer_len:
            data = self.sock.recv( min(self.buff_size, tcp.response_len-buffer_len) )
            if DEBUG == 2: print "\trecv:", data, 'from', self.c_s_pair
            if DEBUG == 3: print "\trecv:", len(data), 'from', self.c_s_pair
            buffer_len += len(data)
        
        self.event.set()
        
    def close(self):
        self.sock.close()

class Sender(object):
    def __init__(self):
        self.send_event = threading.Event()

    def next(self, client, tcp, timing):
        if timing:
            try:
                time.sleep((self.time_origin + tcp.timestamp) - time.time())
            except:
                pass
        t = threading.Thread(target=client.single_tcp_request_response, args=(tcp, self.send_event,))
        t.start()
        return t
    
    def run(self, Q, c_s_pair_mapping, timing):
        progress_bar = print_progress(len(Q))
        self.time_origin = time.time()
        threads = []
        for tcp in Q:
            if DEBUG == 4: progress_bar.next()
            '''
            For every TCP packet:
                1- Wait until client.event is set --> client is not receiving a response
                2- Send tcp payload [and receive response] by calling next
                3- Wait until send_event is set --> sending is done
            '''
            client = c_s_pair_mapping[tcp.c_s_pair]
            client.event.wait()
            client.event.clear()
            threads.append(self.next(client, tcp, timing))
            self.send_event.wait()
            self.send_event.clear()
        
        map(lambda x: x.join(), threads)
            
class SideChannel(object):
    '''
    Client uses SideChannel to:
        0- Initiate SideChannel connection
        1- Identify itself to the server (by sending id;replay_name)
        2- Receive port mapping from the server (useful if server not user original ports)
        3- Request and receive results (once done with the replay)
        4- At this point, the server itself will close the connection
    '''
    def __init__(self, instance, buff_size=4096):
        self.instance  = instance
        self.buff_size = buff_size
        self.sock      = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
        self.sock.connect((self.instance.ip, self.instance.port))

    def identify(self, id, replay_name):
        self.send_object(';'.join([id, replay_name]))

    def receive_server_port_mapping(self):
        data = self.receive_object()
        if not data:
            return {}
        return pickle.loads(data)

    def get_result(self, outfile=None, result=False):
        if not result:
            self.send_object('NoResult')
            return
        
        self.send_object( 'GiveMeResults' )
        result = self.receive_object()
        if outfile is not None:
            f = open(outfile, 'wb')
            f.write(result)
        return result
    
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
    
    def terminate(self):
        self.sock.shutdown(socket.SHUT_RDWR)
        self.sock.close()

def id_generator(size=10, chars=string.ascii_letters + string.digits):
    return ''.join(random.choice(chars) for x in range(size))

def create_test_Q():
    '''
    Making a test random Q
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

def load_Q(test, serialize='pickle'):
    '''
    This loads and de-serializes all necessary objects.
    
    NOTE: the parser encodes all packet payloads into hex before serializing them.
          So we need to decode them before starting the replay, hence the loop at
          the end of this function.
    '''
    if test:
        Q, c_s_pairs, replay_name = create_test_Q()
    
    else:
        for file in os.listdir(Configs().get('pcap_folder')):
            if file.endswith('_client_' +serialize):
                pickle_file = os.path.abspath(Configs().get('pcap_folder')) + '/' + file
                break
        if serialize == 'pickle':
            Q, c_s_pairs, replay_name = pickle.load(open(pickle_file, 'r'))
        elif serialize == 'json':
            Q, c_s_pairs, replay_name = json.load(open(pickle_file, 'r'), cls=TCPjsonDecoder_client)
    
    for tcp in Q:
        tcp.payload = tcp.payload.decode('hex')
    
    return Q, c_s_pairs, replay_name

def run(*args):
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
    Q, c_s_pairs, replay_name = load_Q(configs.get('test'), configs.get('serialize'))

    PRINT_ACTION('Creating side channel, identifying, and receiving server port mapping', 0)
    side_channel = SideChannel(SocketInstance(configs.get('instance').host, side_channel_port))
    side_channel.identify(id, replay_name)
    server_port_mapping = side_channel.receive_server_port_mapping()
    
    PRINT_ACTION('Creating all client sockets', 0)
    c_s_pair_mapping = {}
    for c_s_pair in c_s_pairs:
        dst_port = int(c_s_pair[-5:])
        if server_port_mapping:
            dst_port = server_port_mapping[dst_port]
        client = Client(configs.get('instance').host, dst_port, c_s_pair, replay_name, id)
        c_s_pair_mapping[c_s_pair] = client

    PRINT_ACTION('Running the Q ...', 0)
    Sender().run(Q, c_s_pair_mapping, configs.get('timing'))
    
    PRINT_ACTION('Receiving results ...', 0)
    side_channel.get_result('result.jpg', result=configs.get('result'))
    
    PRINT_ACTION('Fin', 0)
    
def main():
    run(sys.argv)
    
if __name__=="__main__":
    main()
