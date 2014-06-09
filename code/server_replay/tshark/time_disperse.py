'''
this looks into UDP parsed data and give the time gaps in streams
'''


import sys, os, pickle


def main():
    pcap_folder = sys.argv[1]
    
    for file in os.listdir(pcap_folder):
        if file.endswith('_client_pickle'):
            client_pickle = os.path.abspath(pcap_folder) + '/' + file
        if file.endswith('_server_pickle'):
            server_pickle = os.path.abspath(pcap_folder) + '/' + file
    
    print client_pickle
    print server_pickle
    
    Q, client_ports, num_server_ports, c_s_pairs, replay_name = pickle.load(open(client_pickle, 'rb'))
    
    maxs = {}
    prev = {}
    
    for udp in Q:
        server_port = udp.c_s_pair[-5:]
        if server_port not in maxs:
            maxs[server_port] = 0
            prev[server_port] = udp.timestamp
        else:
            maxs[server_port] = max( maxs[server_port], udp.timestamp-prev[server_port] )
            prev[server_port] = udp.timestamp
    
    for server_port in sorted(maxs.keys()):
        if maxs[server_port] > 0 : print server_port, ':', maxs[server_port]
    
    print max(maxs.values())
    
if __name__=="__main__":
    main()