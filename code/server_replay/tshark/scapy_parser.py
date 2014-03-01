'''
Queue:
    queue = [ [req, c_s_pair, hash(res), len(res), timestamp], ...]

Table:
    table[c_s_pair] = [ [len(req), hash(rea), [[res, timestamp], ...] ], ...]

packet_dic:
    packet_dic[c_s_pair][pl_hash] = [[timestamp, talking]]
'''

import pickle, copy, os, sys, linecache, ConfigParser
import python_lib
from python_lib import *
from scapy.all import *
from scapy.error import Scapy_Exception

DEBUG0 = False

def read_packet_file(packet_file):
    packet_dic = {}
    
    f = open(packet_file, 'r')

    l = f.readline()
    while l:
        l = l.strip()
        a = l.split('\t')
        
        timestamp = float(a[0])
        c_s_pair  = a[1]
        talking   = a[2]
        pl_hash   = int(a[3])
        
#        if '010.011.003.003.39114-107.022.180.095.00443' == c_s_pair:
#            print pl_hash
#            print a[4]
            
        if c_s_pair not in packet_dic:
            packet_dic[c_s_pair] = {}
        
        if pl_hash not in packet_dic[c_s_pair]:
            packet_dic[c_s_pair][pl_hash] = [[timestamp, talking]]
        
        else:
            packet_dic[c_s_pair][pl_hash].append([timestamp, talking])
        l = f.readline()
    
    return packet_dic
def stream_to_queue(stream_file, packet_dic):
    client   = convert_ip(((linecache.getline(stream_file, 5)).split()[2]).replace(':', '.'))
    server   = convert_ip(((linecache.getline(stream_file, 6)).split()[2]).replace(':', '.'))
    c_s_pair = client + '-' + server
    
    print c_s_pair
    
    f = open(stream_file, 'r')
    
    for i in range(6):
        f.readline()
    
    queue     = []
    table     = []

    pl1      = (f.readline()).strip()
    pl1_hash = hash(pl1)
    try:
        info1 = packet_dic[c_s_pair][pl1_hash].pop(0)
    except KeyError:
        print 'Broken stream file!', stream_file
        return queue, table, c_s_pair
    pl1_timestamp = info1[0]
    pl1_talking   = info1[1]
    
    while pl1 and pl1[0] != '=':
        assert(pl1_talking == 'c')
        
        res_list = []
        req = pl1.decode("hex")
        res = ''
    
        pl2 = (f.readline()).strip()    
        while pl2 and pl2[0] != '=':
            pl2_hash      = hash(pl2)
#            info2         = packet_dic[c_s_pair][pl2_hash].pop(0)
            try:
                info2 = packet_dic[c_s_pair][pl2_hash].pop(0)
            except KeyError:
                print 'Payload not in packet dic:'
                print pl2
                pl2 = (f.readline()).strip()
                continue
            pl2_timestamp = info2[0]
            pl2_talking   = info2[1]
            
            if pl2_talking == 'c':
#                queue.append([pl1.decode("hex"), c_s_pair, None, 0, pl1_timestamp])
                queue.append( RequestSet(pl1.decode("hex"), c_s_pair, None, pl1_timestamp) )
                req          += pl2.decode("hex")
                pl1           = pl2
                pl1_hash      = pl2_hash
                pl1_timestamp = pl2_timestamp
                pl1_talking   = pl2_talking
                
                pl2 = (f.readline()).strip()
            
            if pl2_talking == 's':
                first = True
                break
       
        while pl2 and pl2[0] != '=':
            pl2_hash      = hash(pl2)
#            print pl2
            if not first:
    #            info2         = packet_dic[c_s_pair][pl2_hash].pop(0)
                try:
                    info2 = packet_dic[c_s_pair][pl2_hash].pop(0)
                except KeyError:
                    print 'Payload not in packet dic:'
                    print pl2
                    pl2 = (f.readline()).strip()
                    continue
                pl2_timestamp = info2[0]
                pl2_talking   = info2[1]
            first = False
            if pl2_talking == 's':
#                res_list.append([pl2.decode("hex"), pl2_timestamp])
                res_list.append( OneResponse(pl2.decode("hex"), pl2_timestamp) )
                res += pl2.decode("hex")
                pl2 = (f.readline()).strip()
            
            if pl2_talking == 'c':
                break
        
#        queue.append([pl1.decode("hex"), c_s_pair, hash(res), len(res), pl1_timestamp])
#        table.append([len(req), hash(req), res_list])
        queue.append( RequestSet(pl1.decode("hex"), c_s_pair, res, pl1_timestamp) )
        table.append( ResponseSet(req, res_list) )

        if pl2[0] == '=':
            break
        pl1           = pl2
        pl1_hash      = pl2_hash
        pl1_timestamp = pl2_timestamp
        pl1_talking   = pl2_talking

    return queue, table, c_s_pair
def map_follows(follows_dir, client_ip):
    '''
    Given a directory of all follow file, created by tshark, does the following:
        - Returns follows_dir[c_s_pair] = corresponding follow file
        - Makes another copy of the follow file with the c_s_pair in the name, just for fun!
        - If a follow file doesn't start by client, prints 'Whaaaaat????'  
    '''
    l     = client_ip.split('.')
    l[:4] = map(lambda x : x.zfill(3), l[:4])
    client_ip = '.'.join(l)
    
    follows_dir = os.path.abspath(follows_dir)
    file_list = python_lib.dir_list(follows_dir, True)
    follow_files = {}
    for file in file_list:
        if ('follow-stream-' not in file):
            continue
        if linecache.getline(file, 7)[0] == '=':
            print 'empty file:', file
            continue
        node0 = convert_ip(((linecache.getline(file, 5)).split()[2]).replace(':', '.'))
        node1 = convert_ip(((linecache.getline(file, 6)).split()[2]).replace(':', '.'))
        c_s_pair = '-'.join([node0, node1])
        if node0.rpartition('.')[0] != client_ip:
            print 'Whaaaaat????', file
        follow_files[c_s_pair] = file 
        outfile = file.rpartition('/')[0] + '/' + c_s_pair + '.' + file.partition('.')[2]
        if os.path.isfile(outfile) is False:
            os.system(('cp ' + file + ' ' + outfile))
    print 'map_follows Done:', len(follow_files)  
    return follow_files
def read_payload(c_s_pair, talking, where_in_file, file):
    node0 = convert_ip(((linecache.getline(file, 5)).split()[2]).replace(':', '.'))
    node1 = convert_ip(((linecache.getline(file, 6)).split()[2]).replace(':', '.'))
    assert(c_s_pair == '-'.join([node0, node1]))

    req_list = []
    res_list = []
    
    l = linecache.getline(file, where_in_file)
    try:
        l[0]
    except:
        print 'Broken file. Empty line!', file
        return None, None, where_in_file
    
    if (l[0] == '='):
        print 'Broken file. = line!', file
        print where_in_file
        print l
        return None, None, where_in_file
    
    while l[0] != '\t':
        req_list.append( ((l.strip())[10:59]).replace(' ', '') )
        where_in_file += 1
        l = linecache.getline(file, where_in_file)
        if (l[0] == '='):
            req = (''.join(req_list)).decode('hex')
            return req, None, where_in_file
#            return None, None, where_in_file
        
    while l[0] == '\t':
        res_list.append( ((l.strip())[10:59]).replace(' ', '') )
        where_in_file += 1
        l = linecache.getline(file, where_in_file)
    
    req = (''.join(req_list)).decode('hex')
    res = (''.join(res_list)).decode('hex')
    
#    print 'req:', req
#    print 'res:', res
    return req, res, where_in_file
def create_packets_file(pcap_file, client_ip, packets_file):
    DEBUG = True
    
    pf = open(packets_file, 'w')
    
    a = rdpcap(pcap_file)
    
    tcp_c             = 0
    tcp_p             = 0
    tcp_irrelevant    = 0
    
    for i in range(len(a)):
        p = a[i]
        try:
            tcp    = p['IP']['TCP']
            tcp_c += 1
            raw    = p['Raw'].load
            tcp_p += 1
        except:
            continue
        
        '''Create c_s_pair'''
        src_p  = p['IP']['TCP'].sport
        dst_p  = p['IP']['TCP'].dport
        src_ip = p['IP'].src
        dst_ip = p['IP'].dst
        #if traffic coming from client
        if client_ip == src_ip:
            client = src_ip + '.' + str(src_p)
            server = dst_ip + '.' + str(dst_p)
            c_s_pair = convert_ip(client) + '-' + convert_ip(server)
            talking = 'c'
        #if traffic coming from server
        elif client_ip == dst_ip:
            server = src_ip + '.' + str(src_p)
            client = dst_ip + '.' + str(dst_p)
            c_s_pair = convert_ip(client) + '-' + convert_ip(server)
            talking = 's'
        raw_hex = raw.encode('hex')
        to_write = str(p.time) + '\t' + c_s_pair + '\t' + talking + '\t' + str(hash(raw_hex)) + '\t' + raw_hex + '\n' 
        pf.write(to_write)    
    
    pf.close()
      
    print '\n'
    print 'Parsed results:'
    print '\tNumber of packets:', len(a)
    print '\tNumber of TCP packets:', tcp_c
    print '\tNumber of TCP packets w/ payload:', tcp_p
    print '\tNumber of irrelevant TCP packets:', tcp_irrelevant
    print '\n'
def sanity_check(queue, table):
    print '\nDoing sanity check...'
    req = {}
    for q in queue:
        pl        = q.payload
        c_s_pair  = q.c_s_pair
        res_hash  = q.response_hash
        res_len   = q.response_len
        timestamp = q.timestamp
        
        if c_s_pair not in req:
            req[c_s_pair] = ''
            req[c_s_pair] = 0
        req[c_s_pair] += len(pl)
        
        if (res_len == 0):
            continue
        res           = table[c_s_pair].pop(0)
        table_req_len = res.request_len
        res_array     = res.response_list
        table_res     = ''.join(map(lambda x: x.payload, res_array))
        assert(table_req_len == req[c_s_pair])
        
        if (res_len != len(table_res)) or (res_hash != hash(table_res)):
            print 'Inconsistency:'
            print pl
            print '===='
            print len(pl)
            print '===='
            print c_s_pair
            print '===='
            print hash(pl)
            print '===='
            print res_hash
            print '===='
            print table[hash(pl)]
            print '===='
            print hash(table[hash(pl)])
            return
        if DEBUG0: print c_s_pair, req[c_s_pair], len(table_res)
        req[c_s_pair] = 0
    print '\tPassed sanity check! Hoooooray!!! :)\n'
def do_tshark_follows(pcap_file, follow_folder):
    command = ("PCAP_FILE='" + pcap_file + "'\n" +
               "follow_folder='" + follow_folder + "'\n" +
               "END=$(tshark -r $PCAP_FILE -T fields -e tcp.stream | sort -n | tail -1)\n" +
               "echo $END+1\n" +
               "for ((i=0;i<=END;i++))\n" +
               "do\n" +
                "\techo $i\n" +
                "\ttshark -r $PCAP_FILE -qz follow,tcp,raw,$i > $follow_folder/follow-stream-$i.txt\n" +
               "done"
              )
    os.system(command)
def main():
    
    All_Hash = False
    
    try:
        pcap_folder = sys.argv[1]
    except:
        print 'Usage: python scapy_parser.py [pcap_folder]'
        sys.exit(-1)
        pcap_folder = '../data/dropbox_d/'
#        client_ip = '10.11.3.3'

    pcap_folder    = os.path.abspath(pcap_folder)
    pcap_file      = pcap_folder + '/' + os.path.basename(pcap_folder) + '.pcap'
    client_ip_file = pcap_folder + '/' + 'client_ip.txt'
    follow_folder  = pcap_folder + '/' + os.path.basename(pcap_folder) + '_follows'
    packets_file   = pcap_file   + '_packets.txt'

    
    if not os.path.isfile(pcap_file):
        print 'The folder is missing the pcap file! Exiting with error!'
        sys.exit(-1)
    if not os.path.isdir(follow_folder):
        print 'Follows folder doesnt exist. Creating the follows folder...'
        os.makedirs(follow_folder)
        do_tshark_follows(pcap_file, follow_folder)
    if not os.path.isfile(client_ip_file):
        print 'The folder is missing the client_ip_file!'
        print 'Will extract this from tshark follows' 
        client_ip = read_client_ip(follow_folder, True)
    else:
        print 'Reading client_ip from:', client_ip_file
        client_ip = read_client_ip(client_ip_file)
    if not os.path.isfile(packets_file):
        print 'The packets_file is missing. Creating it right now...'
        create_packets_file(pcap_file, client_ip, packets_file)
        
    comm_file   = pcap_file + '_communication.txt'
    config_file = pcap_file + '_config'
    
    print 'pcap_folder:', pcap_folder
    print 'client_ip:  ', client_ip

    packet_dic = read_packet_file(packets_file)
    
    queue = []
    table = {}
    
    file_list = python_lib.dir_list(follow_folder, True)
    for file in file_list:
        if ('follow-stream-' not in file):
            continue
        [q, t, c_s_pair] = stream_to_queue(file, packet_dic)
        queue += q
        table[c_s_pair] = t
    
    queue.sort(key=lambda q: q.timestamp)

    time_origin = queue[0].timestamp
    for q in queue:
        setattr(q, 'timestamp',  q.timestamp - time_origin)
            
    for c_s_pair in table:
        for i in range(len(table[c_s_pair])):
            if len(table[c_s_pair][i].response_list) == 0:
                continue 
            time_offset = table[c_s_pair][i].response_list[0].timestamp
            for j in range(len(table[c_s_pair][i].response_list)):
#                table[c_s_pair][i][2][j][1] -= time_offset
                table[c_s_pair][i].response_list[j].timestamp -= time_offset
                
    
    if DEBUG0:
        print 'QUEUE:'
        i = 0
        for q in queue:
            i += 1
            print i, q.c_s_pair, '\t', q.timestamp, '\t', len(q.payload), '\t', q.response_len
        
        print 'TABLE:'
        for c_s_pair in table:
            print '\n---', c_s_pair, '---'
            for t in table[c_s_pair]:
                print c_s_pair, '\t', t.request_len, len(''.join(map(lambda x: x.payload, t.response_list)))
    

    sanity_check(queue, copy.deepcopy(table))

    pickle.dump(queue, open((pcap_file+'_client_pickle'), "wb" ))
    pickle.dump(table, open((pcap_file+'_server_pickle'), "wb" ))
    
    Config = ConfigParser.ConfigParser()
    Config.add_section('Section1')
    Config.set('Section1', 'All_Hash',False)
    Config.set('Section1', 'pcap_file', os.path.relpath(pcap_file, os.getcwd()))
    Config.set('Section1', 'number_of_servers', len(table))
    
    Config.write(open(config_file, 'w'))
    
#    print 'len(all_pairs):', len(all_pairs), '\n'
    

#    f = open(comm_file, 'w')
#    for i in range(len(queue)):
#        q = queue[i]
#        c_s_pair = q[1]
#        if All_Hash is True:
#            to_write_req = str(i) + '\tc\t' + str(q[0]) + '\t' + str(q[1]) + '\t' + str(q[2]) + '\n'
#            to_write_res = str(i) + '\ts\t' + str(table[q[0]]) + '\t' + str(table[q[0]]) + '\n'
#            to_write = to_write_req + to_write_res
#        else:
#            to_write_req = str(i) + '\tc\t' + str(len(q[0])) + '\t' + str(q[1]) + '\t' + str(hash(q[0])) + '\n'
##            res = table[ hash(q[0]) ].pop(0)
#            res = (table[c_s_pair].pop(0))[2]
#            if res is not None:
#                to_write_res = str(i) + '\ts\t' + str( len(res) ) + '\t' + str(q[1]) + '\t'  + str(hash(res)) + '\n'
#            else:
#                to_write_res = str(i) + '\ts\t' + '0' + '\t' + str(q[1]) + '\t'  + str(res) + '\n'
#            
#            to_write = to_write_req + to_write_res
#        f.write(to_write)
#        f.write('\n')
#    f.close()
    
if __name__=="__main__":
    main()