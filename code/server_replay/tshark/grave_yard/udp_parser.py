'''
#######################################################################################################
#######################################################################################################

by: Arash Molavi Kakhki (arash@ccs.neu.edu)
    Northeastern University
    
Goal: parses a UDP pcap into replay objects

Usage:
    python udp_parser.py --pcap_folder=[]
    
    Mandatory:
        --pcap_folder: must contain pcap file and clinet_ip.txt
    
    optional:
        --cut_off: toss c_s_pairs who's #packets is less than cut_off percent of biggest c_s_pair.
                   default = 0 --> don't toss anything.

#######################################################################################################
#######################################################################################################
'''

import sys, pickle, json, string, random
from python_lib import *
from scapy.all import *

DEBUG = 0

def random_hex(size, chars='abcdef0123456789'):
    return ''.join(random.choice(chars) for _ in range(size))

def parse(pcap_file, client_ip, replay_name, random_bytes, cut_off=0):
    '''
    This function parses a UDP pcap file (main traffic over UDP) and creates pickle dumps of
    following objects:
        
        For client:
            1) client_Q      = [UDPSet, UDPSet, ...]
            2) c_s_pairs[c_s_pair] = [#packet from client, #packet from server]
        For server:
            3) server_Q[c_s_pair] = [UDPSet, UDPSet, ...]
            4) server_ports[server_port] = [c_s_pair, c_s_pair, ...]

    NOTE: we assume a request-response setting, meaning the traffic ALWAYS starts
          with a packed from client (will be validated once parsing more real traffic pcaps)
    '''
    
    has_begin = []
    
    udp_counter = 0
    udp_total   = 0
    tcp_counter = 0
    tcp_total   = 0
    
    client_Q  = []
    server_Q  = {}
    server_time_origins = {}
    c_s_pairs = {}
    client_ports = []
    server_ports = {}
    time_origin = None
    
    a = rdpcap(pcap_file)
    for i in range(len(a)):
        p = a[i]
        
        try:
            udp = p['IP']['UDP']
            udp_total += 1
            raw = p['Raw'].load
            udp_counter += 1
        except:
            '''The following try-except is just to count TCP packets'''
            try:
                tcp = p['IP']['TCP']
                tcp_total += 1
                raw = p['Raw'].load
                tcp_counter += 1
            except:
                pass
            
            continue
        
        raw = raw.encode("hex")
        
        if random_bytes:
            raw = random_hex(len(raw))
        
        src_p  = p['IP']['UDP'].sport
        dst_p  = p['IP']['UDP'].dport
        src_ip = p['IP'].src
        dst_ip = p['IP'].dst
        
        
        '''
        time_origin is the time of the very first client UDP packet.
        
        server_time_origins[c_s_pair] is the very first time we see a client UDP
        packet on that c_s_pair, so it serves as the time origin for server packets 
        
        NOTE: we assume a request-response setting, meaning the traffic ALWAYS starts
              with a packed from client
        '''
        
        
        if client_ip == src_ip:
            if time_origin == None:
                time_origin = p.time
                
            client      = src_ip + '.' + str(src_p)
            server      = dst_ip + '.' + str(dst_p)
            c_s_pair    = convert_ip(client) + '-' + convert_ip(server)

            client_port = str(src_p).zfill(5)
            server_port = str(dst_p).zfill(5)            
            port_pair   = client_port + '-' + server_port
            
            has_begin.append(c_s_pair)
            
            talking     = 'c'
            
            client_Q.append(UDPset(raw, p.time-time_origin, c_s_pair, client_port=client_port))
            if server_port not in server_Q:
                server_Q[server_port] = []
                server_time_origins[server_port] = p.time
            
        elif client_ip == dst_ip:
            
            if time_origin == None:
                continue
                
            server      = src_ip + '.' + str(src_p)
            client      = dst_ip + '.' + str(dst_p)
            c_s_pair    = convert_ip(client) + '-' + convert_ip(server)
            
            client_port = str(dst_p).zfill(5)
            server_port = str(src_p).zfill(5)
            port_pair = client_port + '-' + server_port

            if c_s_pair not in has_begin:
                continue 
            
            talking     = 's'
            server_Q[server_port].append(UDPset(raw, p.time-server_time_origins[server_port], c_s_pair))
        
        else:
            continue
    
        if server_port not in server_ports:
            server_ports[server_port] = []
        
        if c_s_pair not in server_ports[server_port]:
            server_ports[server_port].append(c_s_pair)
        
        if client_port not in client_ports:
            client_ports.append(client_port)
        
        if c_s_pair not in c_s_pairs:
            c_s_pairs[c_s_pair] = [0, 0]
        
        if talking == 'c':
            c_s_pairs[c_s_pair][0] += 1
        else:
            c_s_pairs[c_s_pair][1] += 1
    
    if DEBUG == 2:    
        for udp in client_Q:
            print udp
        
        for server_port in server_Q:
            print server_port
            for udp in server_Q[server_port]:
                print '\t', udp
    
    print 'Before cut off:'
    print '\tNumber of distinct c_s_pairs:', len(c_s_pairs)
    print '\tNumber of distinct server ports:', len(server_ports)
    print '\t# of packets:', len(client_Q) + sum([len(server_Q[server_port]) for server_port in server_Q])
    print '\t# of client packets:', len(client_Q)
    print '\t# of server packets:', sum([len(server_Q[server_port]) for server_port in server_Q])

#     '''
#     This part cuts off small c_s_pairs
#     '''    
#     if cut_off > 0:
#         max_c_s_pair = max([sum(c_s_pairs[c_s_pair]) for c_s_pair in c_s_pairs])
#         print 'max c_s_pair:', max_c_s_pair
#         
#         for c_s_pair in list(c_s_pairs.keys()):
#             if sum(c_s_pairs[c_s_pair]) < (cut_off/100.0) * max_c_s_pair:
#                 del c_s_pairs[c_s_pair]
#                 del server_Q[c_s_pair]
#                 server_ports[c_s_pair[-5:]].remove(c_s_pair)
#         
#         new_client_Q = []
#         for udp in client_Q:
#             if udp.c_s_pair in c_s_pairs:
#                 if len(new_client_Q) == 0:
#                     time_origin = udp.timestamp
#                 udp.timestamp = udp.timestamp - time_origin
#                 new_client_Q.append(udp)
#         client_Q = new_client_Q
#         
#         
#         for server_port in list(server_ports.keys()):
#             if len(server_ports[server_port]) == 0:
#                 del server_ports[server_port]
#     '''
#     This part is to add end of streams
#     '''
#     new_client_Q = []
#     so_far_client_ports  = []
#     for udp in client_Q[::-1]:
#         if udp.client_port not in so_far_client_ports:
#             so_far_client_ports.append(udp.client_port)
#             new_client_Q.append( UDPset('', -1, '', client_port=udp.client_port, end=True) )
#         new_client_Q.append( udp )
#             
#     new_client_Q.reverse()
#     pickle.dump((new_client_Q, c_s_pairs, replay_name)   , open((pcap_file+'_client_pickle'), "wb" ), 2)
    
    '''
    ############################################
    This is to add keep-alive packets
    ############################################
    '''
    new_client_Q = []
    prev_time = {}
    
    for udp in client_Q:
        
        new_client_Q.append(udp)
        
        server_port = udp.c_s_pair[-5:]
        
        if server_port not in prev_time:
            prev_time[server_port] = udp.timestamp
        else:
            diff = udp.timestamp - prev_time[server_port]
            if diff < 30:
                continue
            number = int(diff/15)
            print server_port, diff, number, prev_time[server_port], udp.timestamp
            for i in range(1, number+1):
                new_udp = UDPset('', prev_time[server_port]+(i*15), udp.c_s_pair, client_port=udp.client_port)
                new_client_Q.append(new_udp)
                if server_port == '62348':
                    print '\t', new_udp
            prev_time[server_port] = udp.timestamp
                    
    
    new_client_Q.sort(key=lambda x: x.timestamp)
    '''############################################'''
    
    
    pickle.dump((new_client_Q, client_ports, len(server_ports), c_s_pairs, replay_name)   , open((pcap_file+'_client_pickle'), "w" ), 2)
    pickle.dump((server_Q, server_ports, replay_name), open((pcap_file+'_server_pickle'), "w" ), 2)

    json.dump((new_client_Q, client_ports, len(server_ports), c_s_pairs, replay_name), open((pcap_file+'_client_json'), "w"), cls=TCP_UDPjsonEncoder)
    json.dump((server_Q, server_ports, replay_name), open((pcap_file+'_server_json'), "w" ), cls=TCP_UDPjsonEncoder)
    
    '''Storing replay name for later reference'''
    f = open((pcap_file+'_replay_name.txt'), 'w')
    f.write(replay_name)
    f.close()
    
    print 'After cut off:'
    print '\tNumber of c_s_pairs:', len(c_s_pairs)
    print '\tNumber of distinct server ports:', len(server_ports)
    print '\t# of packets:', len(client_Q) + sum([len(server_Q[server_port]) for server_port in server_Q])
    print '\t# of client packets:', len(client_Q)
    print '\t# of server packets:', sum([len(server_Q[server_port]) for server_port in server_Q])
    
    print 'tcp_counter:', tcp_counter, tcp_total
    print 'udp_counter:', udp_counter, udp_total
    print client_ports
    
    print 'kir'
    print len(server_Q)
    
def main():
    configs = Configs()
    configs.set('cut_off', 0)
    configs.set('random_bytes', False)
    
    configs.read_args(sys.argv)
    configs.is_given('pcap_folder')
    configs.show_all()
    
    for file in os.listdir(configs.get('pcap_folder')):
        if file.endswith('.pcap'):
            pcap_file = os.path.abspath(configs.get('pcap_folder')) + '/' + file
            replay_name = file.partition('.pcap')[0]
        if file == 'client_ip.txt':
            client_ip_file = os.path.abspath(configs.get('pcap_folder')) + '/' + file
        
    if not os.path.isfile(client_ip_file):
        print 'The folder is missing the client_ip_file!'
        sys.exit(-2)
    
    if not configs.is_given('replay_name'):
        configs.set('replay_name', replay_name)
        print 'Replay name not given. Naming it after the pcap_file:', configs.get('replay_name')
    
    client_ip = read_client_ip(client_ip_file)
    print 'client_ip:', client_ip 
    parse(pcap_file, client_ip, configs.get('replay_name'), configs.get('random_bytes'), cut_off=configs.get('cut_off'))

if __name__=="__main__":
    main()