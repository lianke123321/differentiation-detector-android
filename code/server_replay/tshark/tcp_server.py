'''
by: Arash Molavi Kakhki (arash@ccs.neu.edu)
    Northeastern University
    
Goal: this is the server side script for our replay system.

Input: a config_file

queue = [ [pl, c-s-pair, hash(response), len(response)], ... ]

'''

import os, sys, socket, pickle, threading, time
import python_lib
from python_lib import Configs

DEBUG0 = False

class Server(object):
    def __init__(self, host, buffer_size = 4096):
        self.buffer_size = buffer_size
        self._host       = host
        self._socket     = None
        self._port       = None
        self._create_socket_server()
    
    def get_port(self):
        return self._port
        
    def _create_socket_server(self):
        port = 7600
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
        while True:
            try:
                sock.bind((self._host, port))
                break
            except:
                port += 1
        sock.listen(1)
        if DEBUG0: print 'Created socket server:', (self._host, port)
        self._port   = port
        self._socket = sock

    def run_socket_server(self, table):
    
        response_set = table.pop(0)
        
        while True:
            if DEBUG0: print '\nServer waiting for connection: ', self._host, ':', self._port
            buffer_len = 0
            connection, client_address = self._socket.accept()
            while True:
                if DEBUG0: print 'waiting for:\t', self._host, ':', self._port, response_set.request_len
                if buffer_len >= response_set.request_len:
                    if DEBUG0: print '\nReceived\t', self._host, ':', self._port, len(buffer), response_set.request_len, '\n' 
                    buffer_len -= response_set.request_len
                    if len(response_set.response_list) == 0:
                        pass
                        if DEBUG0: print 'No need to send back anything!', self._host, ':', self._port
                    else:
                        if DEBUG0: print '\nSending\t', self._host, ':', self._port, len(response_set.response_list), '\n'
                        time_origin = time.time()
                        
                        for i in range(len(response_set.response_list)):
                            res       = response_set.response_list[i].payload
                            timestamp = response_set.response_list[i].timestamp
                            if time.time() < time_origin + timestamp:
                                time.sleep((time_origin + timestamp) - time.time())
                            connection.sendall(str(res))
                            if DEBUG0: print '\tSent\t', i+1, '\t', len(res) 
                    if len(table) > 0:
                        response_set = table.pop(0)
                    else:
                        break
                else:
                    buffer_len += len(connection.recv(self.buffer_size))
    
            print 'Done with:', self._host, ':', self._port
            time.sleep(2)
            connection.shutdown(socket.SHUT_RDWR)
            connection.close()

def main():
    '''Defaults'''
    port_file = '/home/arash/public_html/free_ports'
    host = '129.10.115.141'

    try:
        pcap_folder = sys.argv[1]
    except:
        print 'USAGE: python tcp_server.py [pcap_folder]'
        print '\tpcap_folder should contain the following files:'
        print '\tconfig_file, client_pickle_dump, server_pickle_dump'
        sys.exit(-1)

    pcap_folder = os.path.abspath(pcap_folder)
    config_file = pcap_folder + '/' + os.path.basename(pcap_folder) + '.pcap_config'
    
    print '[0]Creating configs (reading configs file and args)'
    configs = Configs(config_file)
    configs.set('host', host)
    configs.set('port_file', port_file)
    
    python_lib.read_args(sys.argv, configs)
    configs.show_all()
    
    ports   = {}
    threads = {} 
    table   = pickle.load(open(configs.get('pcap_file') +'_server_pickle', 'rb'))
    
    print '[1]Creating all socket servers'
    for c_s_pair in table:
        threads[c_s_pair] = Server(Configs().get('host'))
        ports[c_s_pair]   = threads[c_s_pair].get_port()

    print '[2]Serializing port mapping to file'
    pickle.dump(ports, open(configs.get('port_file'), "wb"))
    
    print '[3]Running servers'    
    for c_s_pair in table:
        t = threading.Thread(target=threads[c_s_pair].run_socket_server, args=[table[c_s_pair]])
        t.start()
    
    print '[4]Done! You can now run your client script.'
    print '   Capture packets on server ports %d to %d' % ((min(ports.items(), key=lambda x: x[1])[1], max(ports.items(), key=lambda x: x[1])[1]))
    
if __name__=="__main__":
    main()
    