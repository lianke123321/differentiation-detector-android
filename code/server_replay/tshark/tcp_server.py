'''
by: Arash Molavi Kakhki (arash@ccs.neu.edu)
    Northeastern University
    
Goal: this is the server side script for our replay system.

Input: a config_file

queue = [ [pl, c-s-pair, hash(response), len(response)], ... ]

ps aux | grep "python" |  awk '{ print $2}' | xargs kill -9

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
#                print port
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
        table_pointer = 0
        if DEBUG == 1: print '\tGot connection: ', connection, client_address
        try:
#            response_set = table.pop(0)
            response_set = table[table_pointer]
            table_pointer += 1
        except IndexError:
            print '\tEmpty connection:', self._host, ':', self._port
            return
        
        buffer_len = 0
        while True:
            if DEBUG == 0: print 'waiting for:\t', self._host, ':', self._port, response_set.request_len
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
#                if len(table) > 0:
#                    response_set = table.pop(0)
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
        if expected_conn_num == 0:
            return
        so_far = 0
        round  = 1
        while True:
            if DEBUG == 1: print '\nServer waiting for connection: ', self._host, ':', self._port
            connection, client_address = self._socket.accept()
            c_s_pair = connection.recv(43)
            t = threading.Thread(target=self.handle_connection, args=[table[c_s_pair], connection, client_address])
            t.start()
            so_far += 1
            if DEBUG == 2: print '\t', self._port, ':', so_far, 'out of', expected_conn_num
            if so_far == expected_conn_num:
                if round >= int(Configs().get('rounds')):
                    break
                round += 1
                print 'Resetting so_far for:', self._port
                so_far = 0
#                if DEBUG == 1: print 'breaking loop for:', self._port
#                break


def read_c_s_pair_to_port(file):
    return pickle.load(open(file, 'rb'))

def run():
    '''Defaults'''
    configs = Configs()
    configs.set('rounds', 1)
    configs.set('vpn-no-vpn', True)
    configs.set('original_ports', True)
    configs.set('host', 'ec2-54-204-220-73.compute-1.amazonaws.com')
    configs.set('ports_file', '/tmp/free_ports')
    
    PRINT_ACTION('Reading configs file and args', 0)
    python_lib.read_args(sys.argv, configs)
    
    print configs.get('pcap_folder')
    try:
        pcap_folder = os.path.abspath(configs.get('pcap_folder'))
    except:
        print 'USAGE: python tcp_server.py pcap_folder=[]'
        print '\tpcap_folder should contain the following files:'
        print '\tconfig_file, client_pickle_dump, server_pickle_dump'
        sys.exit(-1)

    config_file = pcap_folder + '/' + os.path.basename(pcap_folder) + '.pcap_config'
    configs.read_config_file(config_file)
    
    configs.show_all()

    if configs.get('vpn-no-vpn'):
        configs.set('rounds', 2*configs.get('rounds'))
    
    PRINT_ACTION('Loading the tables', 0)
    table   = pickle.load(open(configs.get('pcap_file') +'_server_pickle', 'rb'))
    ports   = {}
    threads = {} 

    PRINT_ACTION('Creating all socket servers', 0)
    distinct_ports = {}
    for c_s_pair in table:
        a = c_s_pair.partition('-')
        node0 = a[0]
        node1 = a[2]
        port0 = node0.rpartition('.')[2]
        port1 = node1.rpartition('.')[2]
        if port1 not in distinct_ports:
            distinct_ports[port1] = 0
            if configs.get('original_ports'):
                threads[port1] = Server(Configs().get('host'), int(port1))
            else:
                threads[port1] = Server(Configs().get('host'))
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
    