import os
import pickle
import python_lib
import scapy_parser


follows_dir = os.path.abspath(follows_dir)

file_list = python_lib.dir_list(follows_dir, True)

all_pairs_tshark = []

for file in file_list:
    f = open(file, 'r')
    f.readline()
    f.readline()
    f.readline()
    f.readline()
    node0 = scapy_parser.convert_ip(((f.readline()).split()[2]).replace(':', '.'))
    node1 = scapy_parser.convert_ip(((f.readline()).split()[2]).replace(':', '.'))
    c_s_pair = '-'.join([node0, node1])
    l = f.readline()
    if l[0] != '=':
        all_pairs_tshark.append(c_s_pair)
    f.close()
    command = 'cp ' + file + ' ' + file.rpartition('/')[0] + '/' + c_s_pair + file.partition('stream')[2]
    os.system(command)
    
pickle_dump = pcap_file + '_all_pairs' 
all_pairs_scapy = pickle.load(open(pickle_dump, 'rb'))
for p in all_pairs_tshark:
    if p not in all_pairs_scapy:
        print p