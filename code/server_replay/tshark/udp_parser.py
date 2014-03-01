import sys, pickle
from python_lib import *
from scapy.all import *

DEBUG = 0

def parse(pcap_file, client_ip, cut_off=0):
    '''
    This function parses a UDP pcap file (main traffic over UDP) and creates pickle dumps of
    following objects:
    
        1) server_Q[c_s_pair] = [UDPSet, UDPSet, ...]
        2) client_Q = [UDPSet, UDPSet, ...]
        3) c_s_pairs = [c_s_pair, c_s_pair, ...]


    NOTE: we assume a request-response setting, meaning the traffic ALWAYS starts
          with a packed from client (will be validated once parsing more real traffic pcaps)
    '''
    
    udp_counter = 0
    client_Q  = []
    server_Q  = {}
    server_time_origins = {}
    c_s_pairs = {}
    server_ports = {}
    time_origin = None
    
    a = rdpcap(pcap_file)
    for i in range(len(a)):
        p = a[i]
        
        try:
            udp = p['IP']['UDP']
            raw = p['Raw'].load
            udp_counter += 1
        except:
            continue
        
        src_p  = p['IP']['UDP'].sport
        dst_p  = p['IP']['UDP'].dport
        src_ip = p['IP'].src
        dst_ip = p['IP'].dst
        
        '''
        time_origin is the time of the very first client udp packet
        
        server_time_origins[c_s_pair] is the very first time we see a client udp
        packet on that c_s_pair, so it serves as the time origin for server packets 
        
        NOTE: we assume a request-response setting, meaning the traffic ALWAYS starts
              with a packed from client
        '''
        
        if time_origin == None:
            time_origin = p.time
        
        if client_ip == src_ip:
            client = src_ip + '.' + str(src_p)
            server = dst_ip + '.' + str(dst_p)
            server_port = str(dst_p).zfill(5)
            talking = 'c'
            c_s_pair = convert_ip(client) + '-' + convert_ip(server)
            client_Q.append(UDPset(raw, p.time-time_origin, c_s_pair))
            if c_s_pair not in server_Q:
                server_Q[c_s_pair] = []
                server_time_origins[c_s_pair] = p.time
            
        elif client_ip == dst_ip:
            server = src_ip + '.' + str(src_p)
            client = dst_ip + '.' + str(dst_p)
            server_port = str(src_p).zfill(5)
            talking = 's'
            c_s_pair = convert_ip(client) + '-' + convert_ip(server)
            server_Q[c_s_pair].append(UDPset(raw, p.time-server_time_origins[c_s_pair], c_s_pair))
    
    
        if server_port not in server_ports:
            server_ports[server_port] = []
        
        if c_s_pair not in server_ports[server_port]:
            server_ports[server_port].append(c_s_pair)
        
        if c_s_pair not in c_s_pairs:
            c_s_pairs[c_s_pair] = [0, 0]
        
        if talking == 'c':
            c_s_pairs[c_s_pair][0] += 1
        else:
            c_s_pairs[c_s_pair][1] += 1
    
    if DEBUG == 2:    
        for udp in client_Q:
            print udp
        
        for c_s_pair in server_Q:
            print c_s_pair
            for udp in server_Q[c_s_pair]:
                print '\t', udp
    
    total = 0
    for server_port in server_ports:
#        print server_port, len(server_ports[server_port])
        total += len(server_ports[server_port])
    
    print total, len(c_s_pairs)
    
    print udp_counter
    
    
    print '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~'
    print len(client_Q), len(server_Q), len(c_s_pairs), len(server_ports)
    
    cut_count = 0
    
    if cut_off > 0:
        max = 0
        for c_s_pair in c_s_pairs:
            if sum(c_s_pairs[c_s_pair]) > max:
                max = sum(c_s_pairs[c_s_pair])
        print 'max:', max
        
        for c_s_pair in list(c_s_pairs.keys()):
            if sum(c_s_pairs[c_s_pair]) < (cut_off/100.0) * max:
                del c_s_pairs[c_s_pair]
                del server_Q[c_s_pair]
                server_ports[c_s_pair[-5:]].remove(c_s_pair)
                cut_count += 1
        
        new_client_Q = []
        for udp in client_Q:
            if udp.c_s_pair in c_s_pairs:
                if len(new_client_Q) == 0:
                    time_origin = udp.timestamp
                udp.timestamp = udp.timestamp - time_origin
                new_client_Q.append(udp)
        client_Q = new_client_Q
        
        
        for server_port in list(server_ports.keys()):
            if len(server_ports[server_port]) == 0:
                del server_ports[server_port]
    
    
    print len(client_Q), len(server_Q), len(c_s_pairs), len(server_ports)
    print 'Cut off {} out of {}'.format(cut_count, total)
    
    pickle.dump((client_Q, c_s_pairs)   , open((pcap_file+'_client_pickle'), "wb" ), 2)
    pickle.dump((server_Q, server_ports), open((pcap_file+'_server_pickle'), "wb" ), 2)
    
def main():
    configs = Configs()
    configs.set('cut_off', 10)
    configs.read_args(sys.argv)
    configs.is_given('pcap_folder')
    configs.show_all()
    
    for file in os.listdir(configs.get('pcap_folder')):
        if file.endswith('.pcap'):
            pcap_file = os.path.abspath(configs.get('pcap_folder')) + '/' + file
        if file == 'client_ip.txt':
            client_ip_file = os.path.abspath(configs.get('pcap_folder')) + '/' + file
        
#    pcap_file      = configs.get('pcap_folder') + '/' + os.path.basename(configs.get('pcap_folder')) + '.pcap'
#    client_ip_file = configs.get('pcap_folder') + '/' + 'client_ip.txt'
    
    if not os.path.isfile(client_ip_file):
        print 'The folder is missing the client_ip_file!'
    
    client_ip = read_client_ip(client_ip_file)
    
    parse(pcap_file, client_ip, cut_off=configs.get('cut_off'))

if __name__=="__main__":
    main()