'''
by: Arash Molavi Kakhki (arash@ccs.neu.edu)
    Northeastern University
    
Goal: this is the server side script for our replay system.

Input: a config_file

queue = [ [pl, c-s-pair, hash(response), len(response)], ... ]

'''

import sys, socket, pickle, threading, time
import python_lib

def find_response(buffer, table, All_Hash):
    if All_Hash is True:
        buffer = int(buffer)
    try:
        return table[hash(buffer)].pop(0)
    except:
        return False
def socket_server_create(host, p, table, All_Hash):
    buff_size = 4096
    port = 7600
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
    while True:
        try:
            sock.bind((host, port))
            p.append(port)
            break
        except:
            port += 1
    sock.listen(1)
    print 'Created socket server:', (host, port)
    
    while True:
        print '\nServer waiting for connection...'
        i = 0
        buffer = ''
        connection, client_address = sock.accept()
        print connection, client_address 
        while True:
            buffer += connection.recv(buff_size)
            response = find_response(buffer, table, All_Hash)
            if response is not False:
                print '\nRcvd\t', connection, client_address, len(buffer), hash(buffer), '\n' 
                buffer = ''
                i += 1
                if response is None:
                    'No need to send back anything!', connection, client_address
                else:
                    print '\nSent\t', connection, client_address, len(response), hash(response), '\n'
                    connection.sendall(str(response))
                
        print 'Done sending...'
        time.sleep(2)
        connection.shutdown(socket.SHUT_RDWR)
        connection.close()
def main():
    DEBUG = False
    
    try:
        config_file = sys.argv[1]
    except:
        print 'USAGE: python tcp_server.py [config_file]'
        sys.exit(-1)

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

    ports   = []
    table   = pickle.load(open(pcap_file +'_server_pickle', 'rb'))
    threads = [] 
    
    for i in range(number_of_servers):
        t = threading.Thread(target=socket_server_create, args=[host, ports, table, All_Hash])
        threads.append(t)

    for i in range(len(threads)):
        print i+1, ':',
        threads[i].start()
    
    while len(ports) != number_of_servers:
        continue
    print 'Dumping ports files'
    pickle.dump(ports, open(port_file, "wb"))
    print ports
    print min(ports), max(ports)
    
    print 'You can now run client side'
    
    for t in threads:
        t.join()
    

if __name__=="__main__":
    main()
    