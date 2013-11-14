'''
by: Arash Molavi Kakhki (arash@ccs.neu.edu)
    Northeastern University
    
Goal: this is the client side script for our replay system.

Input: a config_file

queue = [ [pl, c-s-pair, hash(response), len(response)], ... ]

'''

import os, sys, socket, pickle, threading, time
from python_lib import * 

def read_ports(ports_pickle_dump):
    if ports_pickle_dump == None:
        ports_pickle_dump = 'achtung.ccs.neu.edu:/home/arash/public_html/free_ports'
    os.system(('scp ' + ports_pickle_dump + ' .'))
    return pickle.load(open('free_ports', 'rb'))
def socket_connect(host, port):
    print 'Connecting to:', host, port
    server_address = (host, port)
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
    sock.connect(server_address)
    return sock        
def send_single_request(req_set, sock, All_Hash, status):
    buff_size = 4096
    
    pld      = str(req_set[0])
    c_s_pair = req_set[1]
    res      = hash(req_set[2])
    res_len  = req_set[3]
    
#    if req_set[2] is None:
#        res = None
#    else:
#        res = hash(req_set[2])

    while status[c_s_pair] is False:
        continue
    status[c_s_pair] = False
    
    print '\nSending:\t %s %d %d \n' % (c_s_pair, len(pld), hash(pld))
    sock.sendall(pld)
    
    if res_len == 0:
        print '\tNo response required'
        return
    
    print '\tWaiting for response...'
    buffer = ''
    while True:
        buffer += sock.recv(buff_size)
#        if All_Hash:
#            buffer = int(buffer)
        if len(buffer) == res_len:
            break
#        if hash(buffer) == res:
#            break
    status[c_s_pair] = True
    print '\nRcieved:\t %s %d %d \n' % (c_s_pair, len(buffer), hash(buffer))
def main():
    DEBUG = False
    
    try:
        config_file = sys.argv[1]
    except:
        print 'USAGE: python tcp_client.py [config_file]'   
        sys.exit(-1)
    
    [All_Hash, pcap_file, number_of_servers] = read_config_file(config_file)
    print 'All_Hash         :', All_Hash
    print 'pcap_file        :', pcap_file
    print 'number_of_servers:', number_of_servers
    
    '''Defaults'''
    port_file = None
    host = '129.10.115.141'
    
    for arg in sys.argv:
        a = (arg.strip()).partition('=')
        if a[0] == 'port_file':
            port_file = a[2]
        if a[0] == 'host':
            host = a[2]
    
    ports = read_ports(port_file)
    queue = pickle.load(open(pcap_file +'_client_pickle', 'rb'))
    
    status = {} #status[c-s-pair] = True if the corresponding connection is ready to send a new request
                #                   False if the corresponding connection is still waiting for the response to previous request
    for q in queue:
        if q[1] not in status:
            status[q[1]] = True
    
    conns = {}  #conns[c-s-pair] = socket
    for i in range(len(queue)):
        print 'doing:', i, '/', len(queue)
        q = queue[i]
        try:
            sock = conns[q[1]]
        except:
            conns[q[1]] = socket_connect(host, ports.pop(0))
            sock  = conns[q[1]]
        t = threading.Thread(target=send_single_request, args=[q, sock, All_Hash, status])
        t.start()
    
if __name__=="__main__":
    main()
    
    
    