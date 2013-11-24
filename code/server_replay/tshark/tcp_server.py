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

def find_response(buffer, table, All_Hash):
    if All_Hash is True:
        buffer = int(buffer)
    try:
        return table[hash(buffer)].pop(0)
    except:
        return False
def create_socket_server(host, ports, c_s_pair):
    port = 7600
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
    while True:
        try:
            sock.bind((host, port))
            ports[c_s_pair] = port
            break
        except:
            port += 1
    sock.listen(1)
    if DEBUG0: print 'Created socket server:', (host, port)
    return sock   
def run_socket_server(host, ports, table, c_s_pair):
    buff_size = 4096

    sock = create_socket_server(host, ports, c_s_pair)
        
    response_set = table.pop(0)
    
    while True:
        if DEBUG0: print '\nServer waiting for connection: ', c_s_pair
        buffer_len = 0
        connection, client_address = sock.accept()
        while True:
            if DEBUG0: print 'waiting for:\t', c_s_pair, response_set.request_len
            if buffer_len >= response_set.request_len:
                if DEBUG0: print '\nReceived\t', c_s_pair, len(buffer), response_set.request_len, '\n' 
                buffer_len -= response_set.request_len
                if len(response_set.response_list) == 0:
                    pass
                    if DEBUG0: print 'No need to send back anything!', c_s_pair
                else:
                    if DEBUG0: print '\nSending\t', c_s_pair, len(response_set.response_list), '\n'
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
                buffer_len += len(connection.recv(buff_size))

        print 'Done with this connection:', c_s_pair
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
    
    configs = Configs(config_file)
    configs.set('host', host)
    configs.set('port_file', port_file)
    
    python_lib.read_args(sys.argv, configs)
    configs.show_all()
    
    ports   = {}
    threads = [] 
    table   = pickle.load(open(configs.get('pcap_file') +'_server_pickle', 'rb'))
    
    for c_s_pair in table:
        t = threading.Thread(target=run_socket_server, args=[host, ports, table[c_s_pair], c_s_pair])
        t.start()
        threads.append(t)
    
    while len(ports) != len(table):
        time.sleep(1)
        continue
    
    print 'Dumping ports files'
    pickle.dump(ports, open(configs.get('port_file'), "wb"))
    print min(ports.items(), key=lambda x: x[1])[1], '-', max(ports.items(), key=lambda x: x[1])[1] 
    
    print '\n####You can now run client side :)####\n'
    
if __name__=="__main__":
    main()
    