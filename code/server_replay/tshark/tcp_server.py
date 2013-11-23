'''
by: Arash Molavi Kakhki (arash@ccs.neu.edu)
    Northeastern University
    
Goal: this is the server side script for our replay system.

Input: a config_file

queue = [ [pl, c-s-pair, hash(response), len(response)], ... ]

'''

import os, sys, socket, pickle, threading, time
import python_lib

def find_response(buffer, table, All_Hash):
    if All_Hash is True:
        buffer = int(buffer)
    try:
        return table[hash(buffer)].pop(0)
    except:
        return False
def socket_server_create(host, ports, table, c_s_pair, All_Hash):
    buff_size = 4096
    port = 7600
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
    while True:
        try:
            sock.bind((host, port))
#            ports.append(port)
            ports[c_s_pair] = port
            break
        except:
            port += 1
    sock.listen(1)
    print 'Created socket server:', (host, port)
    
    table_set = table.pop(0)
    req_len   = table_set.request_len
    req_hash  = table_set.request_hash
    res_array = table_set.response_list
    
    while True:
        print '\nServer waiting for connection...'
        buffer_len = 0
        connection, client_address = sock.accept()
        while True:
#            print 'waiting for:\t', c_s_pair, req_len
            if buffer_len >= req_len:
#                print '\nReceived\t', c_s_pair, len(buffer), req_len, '\n' 
                buffer_len -= req_len
                if len(res_array) == 0:
                    pass
#                    print 'No need to send back anything!', c_s_pair
                else:
#                    print '\nSending\t', c_s_pair, len(res_array), '\n'
                    time_origin = time.time()
                    
                    for i in range(len(res_array)):
                        res       = res_array[i].payload
                        timestamp = res_array[i].timestamp
#                        while timestamp + time_origin > time.time():
#                            continue
                        if time.time() < time_origin + timestamp:
                            time.sleep((time_origin + timestamp) - time.time())
                        connection.sendall(str(res))
#                        print '\tSent\t', i+1, '\t', len(res) 
                if len(table) > 0:
                    table_set = table.pop(0)
                    req_len   = table_set.request_len
                    req_hash  = table_set.request_hash
                    res_array = table_set.response_list
                else:
                    break
            else:
#                buffer += connection.recv(buff_size)
                buffer_len += len(connection.recv(buff_size))
        print 'Done with this connection:', c_s_pair
        time.sleep(2)
        connection.shutdown(socket.SHUT_RDWR)
        connection.close()

def main():
    DEBUG = False
    
    try:
        pcap_folder = sys.argv[1]
    except:
        print 'USAGE: python tcp_server.py [pcap_folder]'
        sys.exit(-1)

    pcap_folder = os.path.abspath(pcap_folder)
    config_file = pcap_folder + '/' + os.path.basename(pcap_folder) + '.pcap_config'
    
    [All_Hash, pcap_file, number_of_servers] = python_lib.read_config_file(config_file)
    print All_Hash, pcap_file, number_of_servers
    
    
    '''Defaults'''
    port_file = '/home/arash/public_html/free_ports'
    host = '129.10.115.141'
    
    for arg in sys.argv:
        a = (arg.strip()).partition('=')
        if a[0] == 'port_file':
            port_file = a[2]
        if a[0] == 'host':
            host = a[2]
    
    ''' table = {hash(client pl), response}'''

    ports   = {}
    threads = [] 
    
    table = {'cs1': [
                     [len('c11'), hash('c11'), 's11'],
                     [len('c12'), hash('c12'), 's12'],
                     [len('c13'), hash('c13'), 's13'],
                     [len('c14'), hash('c14'), 's14'],
                     [len('c15'), hash('c15'), 's15'],
                     [len('c16'), hash('c16'),  None]
                     ],
             'cs2': [
                     [len('c21'), hash('c21'), 's21'],
                     [len('c22'), hash('c22'), 's22']
                     ]
             }
    
    table   = pickle.load(open(pcap_file +'_server_pickle', 'rb'))
    
    for c_s_pair in table:
        t = threading.Thread(target=socket_server_create, args=[host, ports, table[c_s_pair], c_s_pair, All_Hash])
        threads.append(t)
    
    for i in range(len(threads)):
        print i+1, ':',
        threads[i].start()
    
    while len(ports) != len(table):
        continue
    print 'Dumping ports files'
    pickle.dump(ports, open(port_file, "wb"))
    print ports
    print min(ports.items(), key=lambda x: x[1])[1], max(ports.items(), key=lambda x: x[1])[1] 
    
    print 'You can now run client side'
    
    for t in threads:
        t.join()
    

if __name__=="__main__":
    main()
    