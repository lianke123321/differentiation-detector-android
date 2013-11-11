import sys, socket, pickle, threading, time
import python_lib

def find_response(buffer, table, All_Hash):
    if All_Hash is True:
        buffer = int(buffer)
    try:
        return table[hash(buffer)]
    except:
        return False
def socket_server_create(host, p, table, All_Hash):
    buff_size = 2048
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
#             print buffer, response
            if response is not False:
                print 'Rcvd\t', connection, client_address 
                buffer = ''
                i += 1
                if response is None:
                    'No need to send back anything!', connection, client_address
                else:
                    connection.sendall(str(response))
                    print 'Sent\t', connection, client_address
#                     print "sent:", response
#                     print 'got req for s[', i, ']'
#                     print 'sent: s[', i, ']'
                
        print 'Done sending...'
        time.sleep(2)
#        connection.recv()
        connection.shutdown(socket.SHUT_RDWR)
        connection.close()
def main():
    DEBUG = False
    
    [All_Hash, pcap_file, number_of_servers] = python_lib.read_config_file('config_file')
    print All_Hash, pcap_file, number_of_servers
    
    
    '''Defaults'''
    host = '129.10.115.141'
    pickle_dump = pcap_file +'_server_pickle'
    
    for arg in sys.argv:
        a = (arg.strip()).partition('=')
        if a[0] == 'port':
            port = a[2]
        if a[0] == 'host':
            host = a[2]
        if a[0] == 'pcap_file':
            pcap_file = a[2]
            pickle_dump = pcap_file +'_server_pickle'

    
    ''' table = {hash(client pl), response}'''

#     table = {hash('c1') : 's1', 
#              hash('c2') : 's2', 
#              hash('c3') : 's3', 
#              hash('c4') : 's4', 
#              hash('c5') : 's5',
#              hash('c6') : 's6', 
#              hash('c7') : 's7', 
#              hash('c8') : 's8', 
#              hash('c9') : 's9', 
#              hash('c10') : 's10' }

    p = []
    table = pickle.load(open(pickle_dump, 'rb'))
    
    threads = [] 
    for i in range(number_of_servers):
        t = threading.Thread(target=socket_server_create, args=[host, p, table, All_Hash])
        threads.append(t)
    for i in range(len(threads)):
        t = threads[i]
        print i+1, ':',
        t.start()
#        time.sleep(1)
    print 'dumping'
    while len(p) != number_of_servers:
        continue
    pickle.dump(p, open('/home/arash/public_html/free_ports', "wb"))
    print p
    print min(p), max(p)
    print 'You can now run client side'
    for t in threads:
        t.join()
    


if __name__=="__main__":
    main()
    