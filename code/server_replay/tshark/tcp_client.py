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
#    print 'Connecting to:', host, port
    server_address = (host, port)
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
    sock.connect(server_address)
    return sock        
def send_single_request(req_set, sock, All_Hash, status, send_status):

    buff_size = 4096

    pld      = str(req_set[0])
    c_s_pair = req_set[1]
    res_len  = req_set[3]
    
    while status[c_s_pair] is False:
        continue
    status[c_s_pair] = False
#    print 'Sending:', c_s_pair, len(pld), '\n'
    sock.sendall(pld)

    send_status[0]   = True
    
    if res_len == 0:
        status[c_s_pair] = True
        return
    
#    buffer = ''
    buffer_len = 0
    while True:
#        buffer += sock.recv(buff_size)
        buffer_len += len(sock.recv(buff_size))
#        if All_Hash:
#            buffer = int(buffer)
#        if len(buffer) == res_len:
        if buffer_len == res_len:
            break
#        if hash(buffer) == res:
#            break
    status[c_s_pair] = True
    
#    print 'Recieved:', c_s_pair, len(buffer), '\n'
def main():
    DEBUG = False
    
    try:
        pcap_folder = sys.argv[1]
    except:
        print 'USAGE: python tcp_client.py [pcap_folder]'   
        sys.exit(-1)
    
    pcap_folder = os.path.abspath(pcap_folder)
    config_file = pcap_folder + '/' + os.path.basename(pcap_folder) + '.pcap_config'
    
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
    
    queue = [['c11', 'cs1', hash('s11'), len('s11')],
             ['c12', 'cs1', hash('s12'), len('s12')],
             ['c13', 'cs1', hash('s13'), len('s13')],
             ['c21', 'cs2', hash('s21'), len('s21')],
             ['c14', 'cs1', hash('s14'), len('s14')],
             ['c22', 'cs2', hash('s22'), len('s22')],
             ['c15', 'cs1', hash('s15'), len('s15')],
             ['c16', 'cs1', None, 0]]
    
    queue = [['c11', 'cs1', hash('s11'), len('s11')],
             ['c12', 'cs1', hash('s12'), len('s12')],
             ['c13', 'cs1', hash('s13'), len('s13')],
             ['c21', 'cs2', hash('s21'), len('s21')],
             ['c14', 'cs1', hash('s14'), len('s14')],
             ['c22', 'cs2', hash('s22'), len('s22')],
             ['c15', 'cs1', hash('s15'), len('s15')],
             ['c16', 'cs1', None, 0]]
    
    queue = pickle.load(open(pcap_file +'_client_pickle', 'rb'))

    status = {} #status[c-s-pair] = True if the corresponding connection is ready to send a new request
                #                   False if the corresponding connection is still waiting for the response to previous request
    send_status = [True]
    
    
    for q in queue:
        c_s_pair = q[1]
        if c_s_pair not in status:
            status[c_s_pair] = True
    
    time_origin = time.time()
    conns = {}  #conns[c-s-pair] = socket
    for i in range(len(queue)):
        print 't count:', threading.activeCount()
        q = queue[i]
        c_s_pair  = q[1]
        timestamp = q[4]
        
        print timestamp
        
        while not send_status[0]:
            continue
        
        send_status[0] = False
        
        while not time.time() > time_origin + timestamp:
            continue
        
        print 'Doing:', i+1, '/', len(queue), c_s_pair, len(q[0]), q[3]
        try:
            sock = conns[c_s_pair]
        except:
            conns[c_s_pair] = socket_connect(host, ports[c_s_pair])
            sock  = conns[c_s_pair]
        t = threading.Thread(target=send_single_request, args=[q, sock, All_Hash, status, send_status])
        t.start()
        
    
if __name__=="__main__":
    main()
    
    
    