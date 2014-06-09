'''
#######################################################################################################
#######################################################################################################

by: Arash Molavi Kakhki (arash@ccs.neu.edu)
    Northeastern University
    
Goal: server script for TCP replay

Usage:
    python tcp_server.py --pcap_folder=[]

Mandatory:
    --pcap_folder: either path to a parsed folder, or a text file where each line is path to a 
                   parsed folder

Optional:
    --original_ports: if true, uses same server ports as seen in the original pcap
                      default: False
    --timing: if true, it respect inter-packet timings seen in the original pcap
              default: True

To kill the server:  
    ps aux | grep "python udp_server.py" |  awk '{ print $2}' | xargs kill -9
#######################################################################################################
#######################################################################################################
'''

import sys, socket, time, threading, multiprocessing, numpy, pickle, random, Queue
from python_lib import *

DEBUG = 1

class TCPServer(object):
    def __init__(self, instance, original_ports, buff_size=4096):
        self.buff_size   = buff_size
        self.instance      = instance
        self.original_port = self.instance.port
        self.sock          = self._create_socket(original_ports)
        
    def _create_socket(self, original_ports):
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        
        if original_ports:
            sock.bind((self.instance.ip, self.instance.port))

        else:
            port = 7600
            while True:
                try:
                    sock.bind((self.instance.ip, port))
                    break
                except socket.error:
                    port += 1

            self.instance.port = port
        
        sock.listen(5)
        print '\tCreated server at: {} (original port: {})'.format(self.instance, self.original_port)
        
        return sock
            
    def run(self, Qs, timing, threads_queue):
        while True:
            connection, client_address = self.sock.accept()
            t = threading.Thread(target=self.handle_connection, args=(Qs, connection, timing, ))
            t.start()
            threads_queue.put(t)
    
    def handle_connection(self, Qs, connection, timing):
        '''
        Steps:
            1- receive id;c_s_pair;replay_name
            2- For every response set:
                a- receive request (while loop)
                b- update buffer_len
                c- send response (for loop)
        '''
        data        = (self.receive_object(connection)).split(';')
        id          = data[0]
        c_s_pair    = data[1]
        replay_name = data[2]

        buffer_len = 0
        for response_set in Qs[replay_name][c_s_pair]:
            while buffer_len < response_set.request_len:
                buffer_len += len(connection.recv(self.buff_size))
            
            buffer_len -= response_set.request_len
            
            time_origin = time.time()
            for response in response_set.response_list:
                if timing:
                    if time.time() < time_origin + response.timestamp:
                        time.sleep((time_origin + response.timestamp) - time.time())
                
                connection.sendall(str(response.payload))
        
        time.sleep(2)
        connection.shutdown(socket.SHUT_RDWR)
        connection.close()
    
    def receive_object(self, connection, obj_size_len=10):
        object_size = int(self.receive_b_bytes(connection, obj_size_len))
        return self.receive_b_bytes(connection, object_size)
    
    def receive_b_bytes(self, connection, b):
        data = ''
        while len(data) < b:
            data += connection.recv( min(b-len(data), self.buff_size) )
        return data
          
    def terminate(self):
        self.sock.close()

class SideChannel(object):
    def __init__(self, instance, server_port_mapping, logger_q, buff_size=4096):
        self.buff_size = buff_size
        self.logger_q  = logger_q
        self.sock      = self.create_socket(instance)
        self.server_port_mapping_pickle = pickle.dumps(server_port_mapping, 2)
    
    def create_socket(self, instance):
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
        sock.bind((instance.ip, instance.port))
        sock.listen(5)
        return sock
    
    def run(self):
        while True:
            connection, client_address = self.sock.accept()
            t = threading.Thread(target=self.handle_connection, args=(connection, ))
            t.start()
    
    def handle_connection(self, connection):
        '''
        Steps:
            1- Receive clients id and replay name (id;replay_name)
            2- Pass id;replay_name to logger
            3- Send the port mapping to client
            4- Wait for results request
            5- Send results to client
            6- Close connection
        '''
        print threading.activeCount()
        
        data = self.receive_object(connection)
        self.logger_q.put(data)
        
        if Configs().get('original_ports'):
            self.send_object(connection, '')
        else:
            self.send_object(connection, self.server_port_mapping_pickle)
        
        data = self.receive_object(connection)
        if data == 'GiveMeResults':
            self.send_reults(connection)
        
        connection.shutdown(socket.SHUT_RDWR)
        connection.close()
    
    def send_reults(self, connection):
        result_file = 'smile.jpg'
        f = open(result_file, 'rb')
        self.send_object(connection, f.read())
            
    def send_object(self, connection, message, obj_size_len=10):
        connection.sendall(str(len(message)).zfill(obj_size_len))
        connection.sendall(message)
    
    def receive_object(self, connection, obj_size_len=10):
        object_size = int(self.receive_b_bytes(connection, obj_size_len))
        return self.receive_b_bytes(connection, object_size)
    
    def receive_b_bytes(self, connection, b):
        data = ''
        while len(data) < b:
            data += connection.recv( min(b-len(data), self.buff_size) )
        return data
    
    def terminate(self):
        self.sock.close()

class SideTasks(object):
    def __init__(self):
        self.logger_q   = Queue.Queue()
        self.cleaner_q  = Queue.Queue()
        self.threads    = {}
        self.sleep_time = 1
        self.max_time   = 1
        
    def run(self):
        threads = []
        threads.append(threading.Thread(target=self.replay_logger))
        threads.append(threading.Thread(target=self.add_threads))
#         threads.append(threading.Thread(target=self.clean_threads))
        
        map(lambda x: x.start(), threads)
    
    def replay_logger(self, replay_log='tcp_replay_log.log'):
        while True:
            client = self.logger_q.get()
            to_write = '\t'.join([time.strftime("%Y-%m-%d;%H:%M:%S", time.gmtime())] + client.split(';'))
            PRINT_ACTION(to_write, 1, action=False)
            append_to_file(to_write, replay_log)
    
    def add_threads(self):
        while True:
            t = self.cleaner_q.get()
            self.threads[t] = time.time()
    
    def clean_threads(self):
        while True:
            for t in self.threads.keys():
                if not t.isAlive():
                    del self.threads[t]
                elif time.time() - self.threads[t] > self.max_time:
                    print '\t\tNeed to kill:', t
            time.sleep(self.sleep_time)
    
def create_test_Qs():
    test_count  = 10
    ports       = [55055, 55056, 55056]
    timestamps  = sorted([abs(numpy.random.normal(loc=1, scale=1, size=None)) for k in range(test_count)])
    timestamps2 = sorted([abs(numpy.random.normal(loc=1, scale=1, size=None)) for k in range(test_count)])
    
    Q = []
    table = {}
    c_s_pairs = []
    for j in range(test_count):
        i = random.randrange(len(ports))
        csp = str(i) + 'XX.XXX.XXX.XXX.XXXXX-XXX.XXX.XXX.XXX.' + str(ports[i])
        if csp not in c_s_pairs:
            c_s_pairs.append(csp)
        payload = 'C' + str(j)
        res = 'S' + str(j)
        response = OneResponse(res, timestamps2[j])
        Q.append( RequestSet(payload, csp, res, timestamps[j] ) )
        if csp not in table:
            table[csp] = []
        table[csp].append( ResponseSet(payload, [response]) )
    
    for tcp in Q:
        print '\t', tcp
    
    for csp in table:
        print csp
        for res in table[csp]:
            print '\t', res
    
    pcap_file = 'tcp_test.pcap'
    pickle.dump((Q, c_s_pairs, 'test'), open((pcap_file+'_client_pickle'), "wb" ))
    pickle.dump((table, list(set(ports)), 'test'), open((pcap_file+'_server_pickle'), "wb" ))
    
def load_Qs(test):
    if test:
        ip = ''
        print 'NO FUNCTION FOR TEST GENERATION!'
        create_test_Qs()
        sys.exit(-1)
    else:
        Qs      = {}
        ports   = set()
        folders = []
        pcap_folder = Configs().get('pcap_folder')
        
        if os.path.isfile(pcap_folder):
            with open(pcap_folder, 'r') as f:
                for l in f:
                    folders.append(l.strip())
        else:
             folders.append(pcap_folder)
        
        for folder in folders:
            if folder == '':
                continue
            
            for file in os.listdir(folder):
                if file.endswith('_server_pickle'):
                    pickle_file = os.path.abspath(folder) + '/' + file
                    break
            
            Q, server_ports, replay_name = pickle.load(open(pickle_file, 'rb'))
            Qs[replay_name] = Q
            
            for port in server_ports:
                ports.add(port)
                
            PRINT_ACTION('Created servers for: ' + replay_name, 1, action=False)
    
    return Qs, ports    
    
def main():
    PRINT_ACTION('Creating variables', 0)
    ip = ''
    sidechannel_port = 55555
    server_port_mapping = {}   #server_port_mapping[server.original_port] = server.instance.port 

    PRINT_ACTION('Reading configs and args', 0)
    configs = Configs()
    configs.set('original_ports', False)
    configs.set('timing', True)
    configs.set('test', False)
    configs.set('replay_log', 'tcp_replay_log.log')
    configs.read_args(sys.argv)
    configs.show_all()
    
    PRINT_ACTION('Loading server queues', 0)
    Qs, server_ports = load_Qs(configs.get('test'))
    
    PRINT_ACTION('Creating and running the SideTasks threads', 0)
    side_tasks = SideTasks()    
    side_tasks.run()

    PRINT_ACTION('Creating and running TCP servers', 0)
    for port in server_ports:
        server = TCPServer(SocketInstance(ip, int(port)), configs.get('original_ports'))
        server_port_mapping[server.original_port] = server.instance.port
        t = threading.Thread(target=server.run, args=(Qs, configs.get('timing'), side_tasks.cleaner_q, ))
        t.start()

    PRINT_ACTION('Creating and running the side channel', 0)
    side_channel = SideChannel(SocketInstance(ip, sidechannel_port), server_port_mapping, side_tasks.logger_q)
    t = threading.Thread(target=side_channel.run)
    t.start()
    
    PRINT_ACTION('READY! You can now run the client script', 0)
    print threading.activeCount()
    
if __name__=="__main__":
    main()
    