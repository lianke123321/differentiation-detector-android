'''
#######################################################################################################
#######################################################################################################

by: Arash Molavi Kakhki (arash@ccs.neu.edu)
    Northeastern University
    
Goal: this is the server side script for TCP replay.

Usage:
    python tcp_server.py --pcap_folder=../data/dropbox_d --instance=achtung --original_ports=False

ps aux | grep "python tcp_server.py" |  awk '{ print $2}' | xargs kill -9

#######################################################################################################
#######################################################################################################
'''

import os, sys, socket, pickle, threading, time, traceback
import python_lib
from python_lib import Configs, PRINT_ACTION

DEBUG = 2

class Server(object):
    def __init__(self, host, port=None, buffer_size = 4096):
        self.buffer_size = buffer_size
        self._host       = host
        self._socket     = None
        self._port       = port
        self._create_socket_server()
    def get_port(self):
        return self._port
    def _create_socket_server(self):
        '''
        Creates socket server and starts listening
        '''
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        if self._port is None:
            port = 7600
            while True:
                try:
                    sock.bind((self._host, port))
                    break
                except:
                    port += 1
            self._port = port
        else:
            try:
                sock.bind((self._host, self._port))
            except:
                print '\nCouldnt open port {}. Make sure you are sudo!\n'.format(self._port)
                traceback.print_exc()
                sys.exit(-1)
        self._socket = sock
        if DEBUG == 0: print 'Created socket server:', (self._host, self._port)
        sock.listen(1)
    def handle_connection(self, table, connection, client_address):
        '''
        table = [ResponseSet, ...]
        ResponseSet has these attributes: request_len, request_hash, and response_list
        '''
        table_pointer = 0
        if DEBUG == 1: print '\tGot connection: ', connection, client_address
        try:
            response_set = table[table_pointer]
            table_pointer += 1
        except IndexError:
            print '\tEmpty connection:', self._host, ':', self._port
            return
        
        buffer_len = 0
        while True:
            if DEBUG == 0: print 'waiting for:\t', self._host, ':', self._port, response_set.request_len
            '''
            Now the server knows it has to receive "response_set.request_len bytes" before responding.
            So it keeps reading until it receives that many bytes
            '''
            if buffer_len >= response_set.request_len:
                if DEBUG == 0: print '\nReceived\t', self._host, ':', self._port, len(buffer), response_set.request_len, '\n' 
                buffer_len -= response_set.request_len
                if len(response_set.response_list) == 0:
                    pass
                    if DEBUG == 0: print 'No need to send back anything!', self._host, ':', self._port
                else:
                    if DEBUG == 0: print '\nSending\t', self._host, ':', self._port, len(response_set.response_list), '\n'
                    time_origin = time.time()
                    
                    for i in range(len(response_set.response_list)):
                        res       = response_set.response_list[i].payload
                        timestamp = response_set.response_list[i].timestamp
                        if time.time() < time_origin + timestamp:
                            time.sleep((time_origin + timestamp) - time.time())
                        connection.sendall(str(res))
                        if DEBUG == 0: print '\tSent\t', i+1, '\t', len(res) 
                if table_pointer < len(table):
                    response_set = table[table_pointer]
                    table_pointer += 1
                else:
                    break
            else:
                buffer_len += len(connection.recv(self.buffer_size))

        if DEBUG == 1: print '\tDone with:', self._host, ':', self._port
        time.sleep(2)
        connection.shutdown(socket.SHUT_RDWR)
        connection.close()
    def run_socket_server(self, table, expected_conn_num):
        '''
        Every time a connection comes in, it dispatches it to a thread to handle the connection
        
        The socket server terminates when all experiment rounds are done
        In each round "expected_conn_num" connections will come in from client  
        '''
        if expected_conn_num == 0:
            return
        
        conns_count = 0 #keeps track of number of connections in each round
        round_count = 1 #keeps track of which round we're in
        
        while True:
            if DEBUG == 1: print '\nServer waiting for connection: ', self._host, ':', self._port
            connection, client_address = self._socket.accept()
            '''
            Every c_s_pair is EXACTLY 43 characters (bytes). 
            c_s_pair = xxx.xxx.xxx.xxx.xxxxx-xxx.xxx.xxx.xxx.xxxxx
                     = clientip.clientport-serverip-serverport
            Since there might be multiple c_s_pairs using the same server port, 
            every time the client opens a connection to the server, the first thing it sends to 
            the server is the c_s_pair. The server gets this c_s_pair, and dispatches 
            a thread with corresponding table, i.e. table[c_s_pair] to handle this connection.
            '''
            c_s_pair = connection.recv(43)
            t = threading.Thread(target=self.handle_connection, args=[table[c_s_pair], connection, client_address])
            t.start()
            conns_count += 1
            if DEBUG == 2: print '\t', self._port, ':', conns_count, 'out of', expected_conn_num
            if conns_count == expected_conn_num:
                if round_count >= int(Configs().get('rounds')):
                    break
                round_count += 1
                print 'Resetting conns_count for:', self._port
                conns_count = 0

def read_c_s_pair_to_port(file):
    return pickle.load(open(file, 'rb'))

def run():
    '''
    ######################################################################################
    Reading/setting configurations
    
    rounds: server needs to know how many rounds we are running the experiment so it can
            detect the end of experiment and close sockets
    vpn-no-vpn: if True, we are running vpn and no-vpn experiments back-to-back
                so each round is actually two runs of the experiment
    original_ports: if we are using random server ports or original server ports seen in
                    the original pcap
    ports_file: if not using original ports, client needs to be informed of the ports socket
                servers are running on. This file holds this information
    instance: holds information about the instance the server is running on (see python_lib.py)
    ######################################################################################
    '''
    PRINT_ACTION('Reading configs file and args', 0)
    configs = Configs()
    configs.set('rounds', 1)
    configs.set('vpn-no-vpn', False)
    configs.set('original_ports', True)
    configs.set('ports_file', '/tmp/free_ports')
    configs.set('instance', 'meddle')   #Add your instance to Instance class in python_lib.py
    
    configs.read_args(sys.argv)
    
    try:
        pcap_folder = os.path.abspath(configs.get('pcap_folder'))
    except:
        print 'USAGE: python tcp_server.py --pcap_folder=[]'
        print '\tpcap_folder should contain the following files:'
        print '\tconfig_file, client_pickle_dump, server_pickle_dump'
        sys.exit(-1)

    config_file = pcap_folder + '/' + os.path.basename(pcap_folder) + '.pcap_config'
    configs.read_config_file(config_file)
    
    configs.set('instance', python_lib.Instance(configs.get('instance')))
    configs.show_all()
    
    #If vpn-no-vpn is set, each round will be 2 runs, one through the vpn, and one direct 
    if configs.get('vpn-no-vpn'):
        configs.set('rounds', 2*configs.get('rounds'))
    
    
    '''
    ######################################################################################
    Loading the table.
    
    Table is a dictionary generated by the parser up front (by scapy_parser.py)
    
    Has the following format (see python_lib):
    
    table[c_s_pair] = [ResponseSet, ...] --> For every c_s_pair, it's a list of OneRespose objects
    
    ######################################################################################
    '''
    PRINT_ACTION('Loading the tables', 0)
    table   = pickle.load(open(configs.get('pcap_file') +'_server_pickle', 'rb'))
    
    
    '''
    ######################################################################################
    Creating and running all socket servers

    c_s_pair is formatted as: "clientip.clientport-serverip.serverport" --> exactly 43 characters
        
    ports: if not using original ports, servers are generated on random ports and notifies
           the client of these ports. In order to do that, we store the mapping of c_s_pair
           to ports in a dictionary called "ports" where the client downloads before replaying
    
    distinct_ports: multiple c_s_pairs using the same server port, so number of distinct ports,
            hence number of distinct socket servers, could be smaller than number of c_s_pairs.
            distinct_ports basically tracks how many c_s_pairs use each server port.
    ######################################################################################
    '''
    PRINT_ACTION('Creating all socket servers', 0)
    ports          = {}
    threads        = {} 
    distinct_ports = {}
    for c_s_pair in table:
        a = c_s_pair.partition('-')
        node0 = a[0]
        node1 = a[2]
        port0 = node0.rpartition('.')[2]
        port1 = node1.rpartition('.')[2]    #This is serverport
        if port1 not in distinct_ports:
            distinct_ports[port1] = 0
            if configs.get('original_ports'):
                threads[port1] = Server(Configs().get('instance').host, int(port1))
            else:
                threads[port1] = Server(Configs().get('instance').host)
            print '\t', port1, ':', threads[port1].get_port()
        if len(table[c_s_pair]) > 0:
            distinct_ports[port1] += 1
        
        ports[c_s_pair] = threads[port1].get_port()
    
    PRINT_ACTION('Running servers', 0)
    for port in distinct_ports:
        t = threading.Thread(target=threads[port].run_socket_server, args=[table, distinct_ports[port]])
        t.start()
    
    if not configs.get('original_ports'):
        time.sleep(1)
        PRINT_ACTION('Serializing port mapping to file', 0)
        pickle.dump(ports, open(configs.get('ports_file'), "wb"))
    
    time.sleep(3)
    PRINT_ACTION('Done! You can now run your client script.', 0)
    print '   Capture packets on server ports %d to %d' % ((min(ports.items(), key=lambda x: x[1])[1], max(ports.items(), key=lambda x: x[1])[1]))

def main():
    run()
    
if __name__=="__main__":
    main()
    