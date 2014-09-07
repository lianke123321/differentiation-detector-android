'''
#######################################################################################################
#######################################################################################################

by: Arash Molavi Kakhki (arash@ccs.neu.edu)
    Northeastern University
    
Goal: server script for UDP replay using gevent

Usage:
    python udp_server_gevent.py --pcap_folder=[path to pcap folder]

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

import sys, time, numpy, pickle
from python_lib import *

import gevent, gevent.pool, gevent.server, gevent.queue
from gevent import monkey
from gevent.coros import RLock

monkey.patch_all()

DEBUG = 4

class UDPServer(object):
    def __init__(self, instance, original_ports, Qs, notify_q, ports_q, greenlets_q, tcpdump_q, timing, buff_size=4096):
        self.instance       = instance
        self.buff_size      = buff_size
        self.original_port  = self.instance[1]
        self.original_ports = original_ports
        self.mapping        = {}    #self.mapping[client_ip][client_port] = (id, server_port, replay_name)
        self.Qs             = Qs
        self.timing         = timing
        self.notify_q       = notify_q
        self.ports_q        = ports_q
        self.greenlets_q    = greenlets_q
        self.tcpdump_q      = tcpdump_q
        self.lock           = RLock()
        
    def run(self, start_port=None):
        
        pool = gevent.pool.Pool(1000)
        
        if self.original_ports:
            self.server = gevent.server.DatagramServer(self.instance, self.handle, spawn=pool)
            self.server.start()
        else:
            port = (start_port)
            while True:
                try:
                    self.server = gevent.server.DatagramServer((self.instance[0], port), self.handle, spawn=pool)
                    self.server.start()
                    break
                except Exception as e:
                    print 'Exception', e, port
                    port += 1
            self.instance = (self.instance[0], port)
    
    def handle(self, data, client_address):
        '''
        Data is received from client_address:
            -if self.mapping[client_ip][client_port] exists --> client has already been identified:
                -if server_port is None --> server has already started sending to this client, no need
                 for any action
                -else, set self.mapping[client_ip][client_port] = (None, None, None) and start sending
                 to client
            -else, the client is identifying, to react.
        '''
        client_ip   = client_address[0]
        client_port = str(client_address[1]).zfill(5)
        
        if DEBUG == 2: print 'got:', data, client_ip, client_port
        if DEBUG == 3: print 'got:', len(data), 'from', client_ip, client_port
#         print 'got:', data, 'from', client_ip, client_port
        
        if client_ip not in self.mapping:
            self.mapping[client_ip] = {}
        
        try:
            [id, original_server_port, original_client_port, replay_name, started] = self.mapping[client_ip][client_port]
            
        except KeyError:
            data = data.split(';')
            
            if len(data) != 4:
                print 'Something is wrong!!! Unknown client:', client_ip, client_port, self.original_port, self.instance
                return
            
            id                   = data[0]
            original_server_port = data[1]
            original_client_port = data[2]
            replay_name          = data[3]
            
            if DEBUG == 2: print 'New port pair:', client_address, original_server_port, original_client_port, id, replay_name
            
            self.mapping[client_ip][client_port] = [id, original_server_port, original_client_port, replay_name, False]
            self.ports_q.put(('NEW', id, client_port))
            self.notify_q.put((id, client_port, 'NOTIFY'))
            self.tcpdump_q.put(('port', id, client_port))
            
            return
        
        
        if started is True:
            return
        
        self.mapping[client_ip][client_port][4] = True
        
        gevent.Greenlet.spawn(self.send_Q, self.Qs[replay_name][original_server_port][original_client_port], time.time(), client_address, id, self.timing)
        
    def send_Q(self, Q, time_origin, client_address, id, timing):
        '''
        Sends a queue of UDP packets to client socket
        '''
        self.greenlets_q.put(gevent.getcurrent())
        
        for udp_set in Q:
            if timing:
                gevent.sleep((time_origin + udp_set.timestamp) - time.time())
            
            with self.lock:
                self.server.socket.sendto(udp_set.payload, client_address)
            
            if DEBUG == 2: print '\tsent:', udp_set.payload, 'to', client_address
            if DEBUG == 3: print '\tsent:', len(udp_set.payload), 'to', client_address
            
        self.ports_q.put(('DONE', id, str(client_address[1]).zfill(5)))

class SideChannel(object):
    def __init__(self, instance, port_map, notify_q, ports_q, greenlets_q, tcpdump_q, mappings, buff_size=4096):
        self.buff_size      = buff_size
        self.notify_q       = notify_q
        self.greenlets_q    = greenlets_q
        self.tcpdump_q      = tcpdump_q
        self.ports_q        = ports_q
        self.all_clients    = {}    #self.all_clients[id] = ClientObj
        self.all_side_conns = {}    #self.all_side_conns[g] = id
        self.instance       = instance
        self.mappings       = mappings
        self.server_port_mapping_pickle = pickle.dumps(port_map, 2)
    
    def run(self):
        '''
        SideChannel has two main method that should be always running
        
            1- wait_for_connections: every time a new connection comes in, it dispatches a 
               thread with target=handle to take care of the connection.
            2- notify_clients: constantly gets jobs from a notify_q and notifies clients.
               This could be acknowledgment of new port (coming from UDPServer.run) or 
               notifying of a send_Q end.
        '''        
        gevent.Greenlet.spawn(self.notify_clients)
#         gevent.Greenlet.spawn(self.clients_list)
        gevent.Greenlet.spawn(self.get_ports)
        
        self.pool   = gevent.pool.Pool(10000)
        self.server = gevent.server.StreamServer(self.instance, self.handle, spawn=self.pool)
        self.server.serve_forever()

    def handle(self, connection, address):
        '''
        Steps:
            0- Put the greenlet on the queue
            1- Receive client id and replay_name (id;replay_name)
            2- Tell side tasks to start tcpdump
            3- add the new client
            4- Send port mapping to client
            5- Receive results request and send back results
            6- Close connection
        '''
        
        #0- Put the greenlet on the queue
        g = gevent.getcurrent()
        self.greenlets_q.put(g)
        
        #1- Receive client id and replay_name (id;replay_name)
        data = self.receive_object(connection)
        if data is None: return
        
        #2- Tell side tasks to start tcpdump
        [id, replay_name] = data.split(';')
        ip                = address[0]
        self.tcpdump_q.put(('start', id, replay_name, ip))
        
        #3- add the new client
        self.all_clients[id]   = ClientObj(id, replay_name, connection, ip)
        self.all_side_conns[g] = id
        g.link(self.side_channel_callback)
        
        #4- Send port mapping to client
        if Configs().get('original_ports'):
            send_result = self.send_object(connection, '')
        else:
            send_result = self.send_object(connection, self.server_port_mapping_pickle)
        if send_result is False: return
        
        #5- Receive results request and send back results
        data = self.receive_object(connection)
        if data is None: return
        
        data = data.split(';')
        if data[0] == 'GiveMeResults':
            self.tcpdump_q.put(('stop', id))
            if self.send_reults(connection) is False: return
        
        elif data[0] == 'NoResult':
            self.tcpdump_q.put(('stop', id))
            pass
        
        #6- Close connection
        connection.shutdown(gevent.socket.SHUT_RDWR)
        connection.close()
    
    def get_ports(self):
        while True:
            (what, id, port) = self.ports_q.get()
            
            if id not in self.all_clients:
                print 'get_ports: Client was disconnected!!!!'
                continue
            
            if what == 'DONE':
                self.all_clients[id].done_ports += 1
                self.notify_q.put((id, port, 'DONE'))
                
            else:
                self.all_clients[id].ports.append(port)
                if DEBUG == 2 : print '\tAdded new port to:', id, port
                
    def side_channel_callback(self, *args):
        '''
        When a side_channel greenlet exits, this function is called and the greenlet is removed
        from self.greenlets dictionary and mapping is cleaned.
        '''
        g  = args[0]
        id = self.all_side_conns[g]
        
        print '\tDONE:', id
        
        for mapping in self.mappings:
            for port in self.all_clients[id].ports:
                try:
                    del mapping[self.all_clients[id].ip][port]
                except KeyError:
                    pass 

        del self.all_clients[id]
        del self.all_side_conns[g]
        
        print '\t', self.all_clients
        print '\t', self.all_side_conns
    
    def notify_clients(self):
        '''
        It constantly reads from notify_q and sends notifications client.
            - command = NOTIFY: was put on queue by UDPServer.handle() to acknowledge
                                client identification
            - command = DONE:   was put on queue by SideChannel.get_ports() to tell client
                                that server is done with this port
        '''
        while True:
            data = self.notify_q.get()
            id      = data[0]
            port    = data[1]
            command = data[2]
            
            if DEBUG == 2: print '\tNOTIFYING:', data, str(port).zfill(5)
            
#             print '\tNOTIFYING:', data
            
            try:
                self.send_object(self.all_clients[id].connection, ';'.join([command, str(port).zfill(5)]) )
            except Exception as e:
                print "Broken connection", type(e), e
                pass
    
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
    
    def send_reults(self, connection):
        result_file = 'smile.jpg'
        f = open(result_file, 'rb')
        return self.send_object(connection, f.read())   
    
class ClientObj(object):
    def __init__(self, id, replay_name, connection, ip):
        self.id          = id
        self.replay_name = replay_name
        self.ip          = ip
        self.time        = time.time()
        self.ports       = []
        self.connection  = connection
        self.done_ports  = 0
    
    def __str__(self):
        return '\t'.join([self.id, self.replay_name, self.ip, str(self.time), str(self.ports)])
    
class SideTasks(object):
    '''
    This class runs as a separate process and does all the logging
    '''
    def __init__(self):
        self.logger_q    = gevent.queue.Queue() #Queue used for logging. SideChannel writes to this queue. Both UDPServers and SideChannel write to this queue.
        self.greenlets_q = gevent.queue.Queue() #Queue used for keeping track of greenlets and killing those dangling. SideChannel writes to this queue.
        self.tcpdump_q   = gevent.queue.Queue()
        self.greenlets   = {}
        self.sleep_time  = 10 * 60
        self.max_time    = 10 * 60
    
    def run(self, replay_log, tcpdump_int='eth0'):
        gevent.Greenlet.spawn(self.replay_logger, replay_log)
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
    
    def replay_logger(self, replay_log):
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
        
def create_test_Qs(ports):
    '''
    ###########################################################################
    Making a test random Q
    
    Qs[c_s_pair] = [UDPset, UDPset, ...]

    UDPset --> payload, timestamp
    ########################################################################### 
    '''
    Q         = {}
    test_count = 10
    ports      = [55055, 55055, 55056]
    for i in range(len(ports)):
        server_port = str(ports[i]).zfill(5)
        c_s_pair = 'XXX.XXX.XXX.XXX.10001-XXX.XXX.XXX.XX' + str(i) + '.' + server_port

        timestamps = sorted([abs(numpy.random.normal(loc=1, scale=1, size=None)) for k in range(test_count)])

        if server_port not in Q:
            Q[server_port] = []
        
        for j in range(test_count):
            payload = str(i) + '-' + str(j)
            Q[server_port].append(UDPset(payload, timestamps[j], c_s_pair))
    
    Qs = {}
    Qs['test'] = Q
    
    for replay_name in Qs:
        print replay_name
        for server_port in Qs[replay_name]:
            Qs[replay_name][server_port].sort(key=lambda x: x.timestamp)
            print '\t', server_port
            for udp in Qs[replay_name][server_port]:
                print '\t\t', udp
    
    return Qs, set(ports)

def load_Qs(test, serialize='pickle'):
    '''
    This loads and de-serializes all necessary objects.
    
    NOTE: the parser encodes all packet payloads into hex before serializing them.
          So we need to decode them before starting the replay, hence the loop at
          the end of this function.
    '''
    if test:
        ip = ''
        Qs, ports = create_test_Qs(ip)
    
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
                if file.endswith(('_server_' + serialize)):
                    pickle_file = os.path.abspath(folder) + '/' + file
                    break
            
            if serialize == 'pickle':
                Q, server_ports, replay_name = pickle.load(open(pickle_file, 'r'))
                
            elif serialize == 'json':
                Q, server_ports, replay_name = json.load(open(pickle_file, "r"), cls=UDPjsonDecoder_server)
            
            Qs[replay_name] = Q
            
            for port in server_ports:
                ports.add(port)
            
            PRINT_ACTION('Loaded for: ' + replay_name, 1, action=False)
    
    for replay_name in Qs:
        for server_port in Qs[replay_name]:
            for client_port in Qs[replay_name][server_port]:
                for udp in Qs[replay_name][server_port][client_port]:
                    udp.payload = udp.payload.decode('hex')
    
    return Qs, ports    
    
def main():
    PRINT_ACTION('Creating variables', 0)
    ip = ''
    sidechannel_port = 55555
    ports_q          = gevent.queue.Queue()     #Queue used by UDPServers to inform side channel about new client ports so it updates mapping
    notify_q         = gevent.queue.Queue()     #Queue used to notify clients that server 1)got identification or 2)is done sending
    mappings         = []                       #mapping[client_ip][client_port] = (id, c_s_pair, replay_name)
    port_map         = {}                       #port_map[server.original_port] = server.instance.port

    PRINT_ACTION('Reading configs and args', 0)
    configs = Configs()
    configs.set('original_ports', False)
    configs.set('timing', True)
    configs.set('test', False)
    configs.set('serialize', 'pickle')
    configs.set('replay_log', 'udp_replay_log.log')
    configs.set('tcpdump_int', 'eth0')
    
    configs.read_args(sys.argv)
    configs.show_all()
    
    PRINT_ACTION('Loading server queues', 0)
    Qs, server_ports = load_Qs(configs.get('test'), serialize=configs.get('serialize'))
    
    PRINT_ACTION('Creating and running SideTasks', 0)
    side_tasks = SideTasks()
    side_tasks.run(configs.get('replay_log'), configs.get('tcpdump_int'))
    
    PRINT_ACTION('Creating and running UDP servers', 0)
    start_port = 49152
    for port in server_ports:
        server = UDPServer((ip, int(port)), configs.get('original_ports'), Qs, notify_q, ports_q, side_tasks.greenlets_q, side_tasks.tcpdump_q, configs.get('timing'))
        server.run(start_port=start_port)
        port_map[server.original_port] = server.instance[1]
        print '\tCreated server at: {} (original port: {})'.format(server.instance, server.original_port)
        start_port = server.instance[1] + 1
        mappings.append(server.mapping)

    PRINT_ACTION('Creating and running the side channel', 0)
    side_channel = SideChannel((ip, sidechannel_port), port_map, notify_q, ports_q, side_tasks.greenlets_q, side_tasks.tcpdump_q, mappings)
    side_channel.run()
    
    PRINT_ACTION('READY! You can now run the client script', 0)
    
    
if __name__=="__main__":
    main()
