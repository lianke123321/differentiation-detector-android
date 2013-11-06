import os, sys, socket, pickle, threading, time
from python_lib import * 

def read_ports(path):
    if path == None:
        path = 'achtung.ccs.neu.edu:/home/arash/public_html/free_ports'
    os.system(('scp ' + path + ' .'))
    return pickle.load(open('free_ports', 'rb'))
def socket_connect(host, port):
    print 'Connecting to:', host, port
    server_address = (host, port)
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
    sock.connect(server_address)
    return sock        
def send_single_request(req_set, sock, All_Hash, status):
    
    c_s_pair = req_set[1]
    
    while status[c_s_pair] is False:
        continue
    
    status[c_s_pair] = False
    
    buff_size = 2048
    
    pld = str(req_set[0])
    svr = req_set[1]
    if req_set[2] is None:
        res = None
    else:
        res = hash(req_set[2])
    
    sock.sendall(pld)
    print 'Sent\t', svr
    print '\twaiting for response...'
    if res is None:
        print '\tNo response required'
        return
    
    buffer = ''
    while True:
        buffer += sock.recv(buff_size)        
        if All_Hash:
            buffer = int(buffer)
        if hash(buffer) == res:
            break
    status[c_s_pair] = True
    print 'Rcvd\t', svr
def main():
    DEBUG = False
    
    [All_Hash, pcap_file, number_of_servers] = read_config_file('config_file')
    print All_Hash, pcap_file, number_of_servers
    
    '''Defaults'''
    ports = read_ports(None)
    host = '129.10.115.141'

    pickle_dump = pcap_file +'_client_pickle'
    
    for arg in sys.argv:
        a = (arg.strip()).partition('=')
        if a[0] == 'port':
            port = a[2]
        if a[0] == 'host':
            host = a[2]
        if a[0] == 'pcap_file':
            pcap_file = a[2]
            pickle_dump = pcap_file +'_client_pickle'
    
    ''' queue = [ [pl, c-s-pair, hash(response)] ]'''
            
#     queue = [['c1' , 's1'],
#              ['c2' , 's1'],
#              ['c3' , 's1'],
#              ['c10', 's2'],
#              ['c4' , 's1'],
#              ['c5' , 's1'],
#              ['c6' , 's1'],
#              ['c7' , 's1'],
#              ['c8' , 's1'],
#              ['c9' , 's1']]
#     queue = [['c1' , 's1' , 's1'],
#              ['c2' , 's1' , 's2'],
#              ['c3' , 's1' , 's3'],
#              ['c10', 's2' , 's10'],
#              ['c4' , 's1' , 's4'],
#              ['c5' , 's1' , 's5'],
#              ['c6' , 's1' , 's6'],
#              ['c7' , 's1' , 's7'],
#              ['c8' , 's1' , 's8'],
#              ['c9' , 's1' , 's9']] 
    
    queue = pickle.load(open(pickle_dump, 'rb'))
    
    status = {} #status[c-s-pair] = True if the corresponding connection is ready to send a new request
                #                   False if the corresponding connection is still waiting for the response to previous request
    for q in queue:
        if q[1] not in status:
            status[q[1]] = True
    
    conns = {}  #conns[c-s-pair] = socket
    for q in queue:
        try:
            sock = conns[q[1]]
        except:
            conns[q[1]] = socket_connect(host, ports.pop(0))
            sock  = conns[q[1]]
        t = threading.Thread(target=send_single_request, args=[q, sock, All_Hash, status])
        t.start()
#        send_single_request(q, sock, All_Hash)

    
if __name__=="__main__":
    main()
    
    
    