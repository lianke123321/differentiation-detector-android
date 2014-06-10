'''
#######################################################################################################
#######################################################################################################

by: Arash Molavi Kakhki (arash@ccs.neu.edu)
    Northeastern University
    
Goal: server script for TCP replay using gevent

Usage:
    python tcp_server_gevent.py --pcap_folder=[path to pcap folder]

Mandatory:
    --pcap_folder: either path to a parsed folder, or a text file where each line is path to a 
                   parsed folder

Optional:
    --original_ports: if true, uses same server ports as seen in the original pcap
                      default: False
    --timing: if true, it respect inter-packet timings seen in the original pcap
              default: True
              False will probably wont perform well with gevent

To kill the server:  
    ps aux | grep "python udp_server.py" |  awk '{ print $2}' | xargs kill -9
    
Qs structure:
    Qs[replay_name] = {c_s_pair:ResponseSet, ...}
    ResponseSet = [OneResponse, ...]
    
#######################################################################################################
#######################################################################################################
'''

import sys, time, pickle, random
from python_lib import *

try:
    import numpy
except:
    print 'NUMPY not available, cannot create random Qs. Otherwise you are fine!'

import gevent, gevent.pool, gevent.server, gevent.queue
from gevent import monkey
monkey.patch_all()

DEBUG = 1

class TCPServer(object):
    def __init__(self, instance, original_ports, timing, Qs, greenlets_q, tcpdump_q, buff_size=4096):
        self.buff_size      = buff_size
        self.timing         = timing
        self.Qs             = Qs
        self.greenlets_q    = greenlets_q
        self.tcpdump_q      = tcpdump_q
        self.instance       = instance
        self.original_ports = original_ports
        self.original_port  = self.instance[1]

    def run(self):
        pool = gevent.pool.Pool(10000)
        
        if self.original_ports:
            server = gevent.server.StreamServer(self.instance, self.handle, spawn=pool)
            server.start()
        
        else:
            port = 49152
            while True:
                try:
                    server = gevent.server.StreamServer((self.instance[0], port), self.handle, spawn=pool)
                    server.start()
                    break
                except Exception as e:
                    if DEBUG == 2 : print e
                    port += 1 
            self.instance = (self.instance[0], port)
    
    def handle(self, connection, address):
        '''
        Steps:
            0- Put the greenlet on greenlets_q
            1- receive id;c_s_pair;replay_name
            2- For every response set:
                a- receive request (while loop)
                b- update buffer_len
                c- send response (for loop)
        
        IMPORTANT: if recv() returns an empty string --> the other side of the 
                   connection (client) is gone! and we just terminate the function 
                   (by calling return)
        '''
        self.greenlets_q.put(gevent.getcurrent())
        
        data = self.receive_object(connection)
        if not data:
            return False
        
        data        = data.split(';')
        id          = data[0]
        c_s_pair    = data[1]
        replay_name = data[2]
        
        self.tcpdump_q.put(('port', id, str(address[1])))
        
        for response_set in self.Qs[replay_name][c_s_pair]:
            buffer_len = 0
            while buffer_len < response_set.request_len:
                new_data = connection.recv( min(self.buff_size, response_set.request_len-buffer_len) )
                if not new_data:
                    return False
                buffer_len += len(new_data)
            
            time_origin = time.time()
            for response in response_set.response_list:
                if self.timing:
                    gevent.sleep(seconds=((time_origin + response.timestamp) - time.time()))
                try:
                    connection.sendall(str(response.payload))
                except:
                    return False
        
#         time.sleep(2)
        connection.shutdown(gevent.socket.SHUT_RDWR)
        connection.close()
    
    def receive_object(self, connection, obj_size_len=10):
        try:
            object_size = int(self.receive_b_bytes(connection, obj_size_len))
        except:
            return None
        return self.receive_b_bytes(connection, object_size)
    
    def receive_b_bytes(self, connection, b):
        data = ''
        while len(data) < b:
            new_data = connection.recv( min(b-len(data), self.buff_size) )
            if not new_data:
                return None
            data += new_data
        return data

class SideChannel(object):
    def __init__(self, instance, server_port_mapping, greenlets_q, tcpdump_q, buff_size=4096):
        self.buff_size   = buff_size
        self.greenlets_q = greenlets_q
        self.tcpdump_q     = tcpdump_q
        self.instance    = instance
        self.server_port_mapping_pickle = pickle.dumps(server_port_mapping, 2)
        self.pool = None
    
    def run(self):
        self.pool   = gevent.pool.Pool(10000)
        self.server = gevent.server.StreamServer(self.instance, self.handle, spawn=self.pool)
        self.server.serve_forever()
    
    def handle(self, connection, address):
        '''
        Steps:
            0- Put the greenlet on greenlets_q
            1- Receive clients id and replay name (id;replay_name)
            2- Tell side tasks to start tcpdump
            3- Send the port mapping to client
            4- Wait for results request
            5- Send results to client
            6- Close connection
        '''
        #0- Put the greenlet on greenlets_q
        self.greenlets_q.put(gevent.getcurrent())
        
        #1- Receive clients id and replay name (data = id;replay_name)
        data = self.receive_object(connection)
        if data is None: return False
        
        #2- Tell side tasks to start tcpdump
        [id, replay_name] = data.split(';')
        self.tcpdump_q.put(('start', id, replay_name, address[0]))
        
        if Configs().get('original_ports'):
            send_result = self.send_object(connection, '')
        else:
            send_result = self.send_object(connection, self.server_port_mapping_pickle)
        
        if send_result is False:
            return
        
        data = self.receive_object(connection)
        if data is None:
            return False

        if data == 'GiveMeResults':
            self.tcpdump_q.put(('stop', id))
            if self.send_reults(connection) is False:
                return
        
        elif data[0] == 'NoResult':
            self.tcpdump_q.put(('stop', id))
            pass
        
        connection.shutdown(gevent.socket.SHUT_RDWR)
        connection.close()
        
        
    def send_reults(self, connection):
        result_file = 'smile.jpg'
        f = open(result_file, 'rb')
        return self.send_object(connection, f.read())
            
    def send_object(self, connection, message, obj_size_len=10):
        try:
            connection.sendall(str(len(message)).zfill(obj_size_len))
            connection.sendall(message)
            return True
        except:
            return False
    
    def receive_object(self, connection, obj_size_len=10):
        try:
            object_size = int(self.receive_b_bytes(connection, obj_size_len))
        except:
            return None
        
        return self.receive_b_bytes(connection, object_size)
    
    def receive_b_bytes(self, connection, b):
        data = ''
        while len(data) < b:
            new_data = connection.recv( min(b-len(data), self.buff_size) )
            if not new_data:
                return None
            data += new_data
        return data

class SideTasks(object):
    def __init__(self):
        self.logger_q    = gevent.queue.Queue()
        self.greenlets_q = gevent.queue.Queue()
        self.tcpdump_q   = gevent.queue.Queue()
        
        self.greenlets  = {}
        self.sleep_time = 10 * 60
        self.max_time   = 10 * 60
        
    def run(self, tcpdump_int='eth0'):
        gevent.Greenlet.spawn(self.replay_logger)
        gevent.Greenlet.spawn(self.add_greenlets)
        gevent.Greenlet.spawn(self.greenlet_cleaner)
        gevent.Greenlet.spawn(self.tcpdumps, tcpdump_int)
    
    def tcpdumps(self, tcpdump_int):
        
        all_clients = {}
        
        while True:
            data = self.tcpdump_q.get()
            command = data[0]
            
            if command == 'start':
                id          = data[1]
                replay_name = data[2]
                ip          = data[3]
                
                client = ReplayObj(id, replay_name, ip, tcpdump_int)
                all_clients[id] = client
                client.dump.start(host=ip)
                
                self.logger_q.put(client.get_info())
            
            elif command == 'stop':
                id = data[1]
                all_clients[id].dump.stop()
                self.logger_q.put(all_clients[id].get_ports())                
                clean_pcap(all_clients[id].dump.dump_name, all_clients[id].ports)
                
                del all_clients[id]
            
            elif command == 'port':
                id   = data[1]
                port = data[2]
                all_clients[id].ports.append(port)
                
    def replay_logger(self, replay_log='tcp_replay_log.log'):
        while True:
            to_write = self.logger_q.get()
            PRINT_ACTION(to_write, 1, action=False)
            append_to_file(to_write, replay_log)
    
    def callback_cleaner(self, *args):
        '''
        When a greenlet is done, this function is called and the greenlet is removed
        from self.greenlets dictionary.
        '''
        del self.greenlets[args[0]]
    
    def print_greenlets(self):
        while True:
            print len(self.greenlets)
            gevent.sleep(1)
    
    def add_greenlets(self):
        '''
        Everytime a clinet connects to the SideChannel or a TCPServer, a greenlet is spawned.
        These greenlets are added to a dictionary with timestamp (using this function) and 
        are garbage collected periodically using greenlet_cleaner() 
        '''
        while True:
            g = self.greenlets_q.get()
            self.greenlets[g] = time.time()
            if DEBUG == 2: print '\tAdded to gevents', len(self.greenlets)
            g.link(self.callback_cleaner)
    
    def greenlet_cleaner(self):
        '''
        This goes through self.greenlets and kills any greenlet which is self.max_time seconds
        or older
        '''
        while True:
            PRINT_ACTION('Cleaning dangling greenlets: {}'.format(len(self.greenlets)), 1, action=False)
            for g in self.greenlets.keys():
                if g.successful():
                    del self.greenlets[g]
                elif time.time() - self.greenlets[g] > self.max_time:
                    g.kill(block=False)
            PRINT_ACTION('Done cleaning: {}'.format(len(self.greenlets)), 1, action=False)
            gevent.sleep(self.sleep_time)
    
def create_test_Qs():
    print 'create_test_Qs is outdated! SORRY!'
    sys.exit(-1)
    
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
    
def load_Qs(test, serialize='pickle'):
    '''
    This loads and de-serializes all necessary objects.
    
    NOTE: the parser encodes all packet payloads into hex before serializing them.
          So we need to decode them before starting the replay, hence the loop at
          the end of this function.
    '''
    
    if serialize == 'json':
        print 'SORRY! JSON IS NOT YET SUPPORTED! USE PICKLE!'
        sys.exit(-1)
    
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
            
            table, server_ports, replay_name = pickle.load(open(pickle_file, 'rb'))
            Qs[replay_name] = table
            
            for port in server_ports:
                ports.add(port)
                
            PRINT_ACTION('Loaded queues for: ' + replay_name, 1, action=False)
    
    for replay_name in Qs:
        for c_s_pair in Qs[replay_name]:
            for response_set in Qs[replay_name][c_s_pair]:
                for one_response in response_set.response_list:
                    one_response.payload = one_response.payload.decode('hex')
                    
    return Qs, ports

def main():
    PRINT_ACTION('Creating variables', 0)
    ip = ''
    sidechannel_port = 55555

    PRINT_ACTION('Reading configs and args', 0)
    configs = Configs()
    configs.set('original_ports', False)
    configs.set('timing', True)
    configs.set('test', False)
    configs.set('serialize', 'pickle')
    configs.set('tcpdump_int', 'eth0')
    configs.set('replay_log', 'tcp_replay_log.log')
    configs.read_args(sys.argv)
    configs.show_all()
    
    PRINT_ACTION('Loading server queues', 0)
    Qs, server_ports = load_Qs(configs.get('test'), configs.get('serialize'))
    
    PRINT_ACTION('Creating and running the SideTasks threads', 0)
    side_tasks = SideTasks()    
    side_tasks.run(configs.get('tcpdump_int'))
 
    PRINT_ACTION('Creating and running TCP servers', 0)
    server_port_mapping = {}   #server_port_mapping[server.original_port] = server.instance.port 
    for port in server_ports:
        server = TCPServer((ip, int(port)), configs.get('original_ports'), configs.get('timing'), Qs, side_tasks.greenlets_q, side_tasks.tcpdump_q)
        server.run()
        server_port_mapping[server.original_port] = server.instance[1]
        PRINT_ACTION(' '.join(['Created socket server:', str(server.original_port), str(server.instance)]), 1, action=False)

    PRINT_ACTION('Creating and running the side channel', 0)
    side_channel = SideChannel((ip, sidechannel_port), server_port_mapping, side_tasks.greenlets_q, side_tasks.tcpdump_q)
    side_channel.run()
    
    PRINT_ACTION('READY! You can now run the client script', 0)
    
if __name__=="__main__":
    main()
    