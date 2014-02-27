import sys, pickle
from python_lib import *
from scapy.all import *

def parse(pcap_file, client_ip):
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
    c_s_pairs = []
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
            c_s_pair = convert_ip(client) + '-' + convert_ip(server)
            client_Q.append(UDPset(raw, p.time-time_origin, c_s_pair))
            if c_s_pair not in server_Q:
                server_time_origins[c_s_pair] = p.time
                
        elif client_ip == dst_ip:
            server = src_ip + '.' + str(src_p)
            client = dst_ip + '.' + str(dst_p)
            c_s_pair = convert_ip(client) + '-' + convert_ip(server)
            if c_s_pair not in server_Q:
                server_Q[c_s_pair] = []
            server_Q[c_s_pair].append(UDPset(raw, p.time-server_time_origins[c_s_pair], c_s_pair))
        
        if c_s_pair not in c_s_pairs:
            c_s_pairs.append(c_s_pair)
        
    for udp in client_Q:
        print udp
    
    for c_s_pair in server_Q:
        print c_s_pair
        for udp in server_Q[c_s_pair]:
            print '\t', udp
    
    print c_s_pairs
    print udp_counter
    
    pickle.dump((client_Q, c_s_pairs) , open((pcap_file+'_client_pickle'), "wb" ), 3)
    pickle.dump(server_Q , open((pcap_file+'_server_pickle'), "wb" ), 3)
    
def main():
    pcap = sys.argv[1]
    parse(pcap, '10.10.108.76')

if __name__=="__main__":
    main()