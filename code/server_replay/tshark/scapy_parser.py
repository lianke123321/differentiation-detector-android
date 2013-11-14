import pickle, copy, os, sys, linecache
import python_lib
from scapy.all import *
from scapy.error import Scapy_Exception

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
def convert_ip(ip):
    '''
    converts ip.port to tcpflow format
    ip.port = 1.2.3.4.1234
    tcpflow format = 001.002.003.00.4.01234
    '''
    l     = ip.split('.')
    l[:4] = map(lambda x : x.zfill(3), l[:4])
    l[4]  = l[4].zfill(5)
    return '.'.join(l)
def read_payload2(c_s_pair, talking, where_in_file, file):
    node0 = convert_ip(((linecache.getline(file, 5)).split()[2]).replace(':', '.'))
    node1 = convert_ip(((linecache.getline(file, 6)).split()[2]).replace(':', '.'))
    assert(c_s_pair == '-'.join([node0, node1]))

    req_list = []
    res_list = []
    
    l = linecache.getline(file, where_in_file)
        
    while l[0] != '\t':
        req_list.append( ((l.strip())[10:59]).replace(' ', '') )
        where_in_file += 1
        l = linecache.getline(file, where_in_file)
        if len(l) == 0:
            print 'Broken file', file
            return None, None, where_in_file
    if (l[0] == '='):
        print 'Broken file', file
        return None, None, where_in_file
    
    while l[0] == '\t':
        res_list.append( ((l.strip())[10:59]).replace(' ', '') )
        where_in_file += 1
        l = linecache.getline(file, where_in_file)
    
    req = (''.join(req_list)).decode('hex')
    res = (''.join(res_list)).decode('hex')
    
#    print 'req:', req
#    print 'res:', res
    return req, res, where_in_file
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
def pcap_to_seq(pcap_file, client_ip, All_Hash, follow_files):
    DEBUG = True
    
    a = rdpcap(pcap_file)
    
    tcp_c             = 0
    tcp_p             = 0
    tcp_irrelevant    = 0
    
    total_client_pl = 0
    total_server_pl = 0
    
    queue         = []
    table         = {}
    talking       = {}
    all_pairs     = []
    where_in_file = {}
    
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
        #if traffic coming from server
        elif client_ip == dst_ip:
            server = src_ip + '.' + str(src_p)
            client = dst_ip + '.' + str(dst_p)
            c_s_pair = convert_ip(client) + '-' + convert_ip(server)
            
        '''Check if c_s_pair is new'''
        if c_s_pair not in all_pairs:
            all_pairs.append(c_s_pair)
            where_in_file[c_s_pair] = 7 #the first 6 lines are meta data
            if client_ip == src_ip:
                talking[c_s_pair] = 's'
            elif client_ip == dst_ip:
                talking[c_s_pair] = 'c'
        
        if (client_ip == src_ip) and (talking[c_s_pair] == 's'):
#            where_in_file[c_s_pair] +=  1
            talking[c_s_pair]        = 'c'
            [req, res, where_in_file[c_s_pair]] = read_payload(c_s_pair, talking[c_s_pair], where_in_file[c_s_pair], follow_files[c_s_pair])
            
            if (req is None) and (res is None):
                continue
            
            if res is None:
                queue.append([req, c_s_pair, res, 0])
            else:
                queue.append([req, c_s_pair, hash(res), len(res)])
                total_server_pl += len(res)

            req_hash = hash(req)
            if req_hash not in table:
                table[req_hash] = [res]
            else:
                table[req_hash].append(res)
            total_client_pl += len(req)

        elif (client_ip == dst_ip):
            talking[c_s_pair] = 's'
                    
    print '\n'
    print 'Parsed results:'
    print '\tNumber of packets:', len(a)
    print '\tNumber of TCP packets:', tcp_c
    print '\tNumber of TCP packets w/ payload:', tcp_p
    print '\tNumber of irrelevant TCP packets:', tcp_irrelevant
    print 'Total client payload:', total_client_pl
    print 'Total server payload:', total_server_pl 
    print '\n'
    return queue, table, all_pairs
def sanity_check(queue, table):
    print '\nDoing sanity check...'
    for q in queue:
        pl       = q[0]
        c_s_pair = q[1]
        res_hash = q[2]
        res_len  = q[3]
        table_res = table[hash(pl)].pop(0)
        
        if (res_len == 0) and (table_res == None):
            continue 
        
        elif res_hash != hash(table_res):
            print 'Inconsistency:'
            print pl
            print '===='
            print hash(pl)
            print '===='
            print c_s_pair
            print '===='
            print res_hash
            print '===='
            print table[hash(pl)]
            print '===='
            print hash(table[hash(pl)])
            return
    print '\tPassed sanity check! Hoooooray!!! :)\n'
def do_tshark_follows(pcap_file, follow_folder):
    command = ("PCAP_FILE='" + pcap_file + "'\n" +
               "follow_folder='" + follow_folder + "'\n" +
               "END=$(tshark -r $PCAP_FILE -T fields -e tcp.stream | sort -n | tail -1)\n" +
               "echo $END+1\n" +
               "for ((i=0;i<=END;i++))\n" +
               "do\n" +
                "\techo $i\n" +
                "\ttshark -r $PCAP_FILE -qz follow,tcp,hex,$i > $follow_folder/follow-stream-$i.txt\n" +
               "done"
              )
    os.system(command)
def read_client_ip(client_ip_file):
    f = open(client_ip_file, 'r')
    return (f.readline()).strip()
def main():
    
    All_Hash = True
    All_Hash = False
    
    try:
        pcap_folder = sys.argv[1]
    except:
        pcap_folder = '../data/dropbox_d/'
        client_ip = '10.11.3.3'

    pcap_folder    = os.path.abspath(pcap_folder)
    pcap_file      = pcap_folder + '/' + os.path.basename(pcap_folder) + '.pcap'
    client_ip_file = pcap_folder + '/' + 'client_ip.txt'
    follow_folder  = pcap_folder + '/' + os.path.basename(pcap_folder) + '_follows'
    
    if not os.path.isfile(pcap_file):
        print 'The folder is missing the pcap file! Exiting with error!'
        sys.exit(-1)
    if not os.path.isfile(pcap_file):
        print 'The folder is missing the client_ip_file! Exiting with error!'
        sys.exit(-1)
    if not os.path.isdir(follow_folder):
        print 'Follows folder doesnt exist. Creating the follows folder...'
        os.makedirs(follow_folder)
        do_tshark_follows(pcap_file, follow_folder)
    
    client_ip = read_client_ip(client_ip_file)
    
    print 'pcap_folder:', pcap_folder
    print 'client_ip:  ', client_ip

    comm_file   = pcap_file + '_communication.txt'
    config_file = pcap_file + '_config'

    
    follow_files = map_follows(follow_folder, client_ip)   
    [queue, table, all_pairs] = pcap_to_seq(pcap_file, client_ip, All_Hash, follow_files)
    
    sanity_check(queue, copy.deepcopy(table))

    pickle.dump(queue, open((pcap_file+'_client_pickle'), "wb" ))
    pickle.dump(table, open((pcap_file+'_server_pickle'), "wb" ))
    pickle.dump(all_pairs, open((pcap_file+'_all_pairs'), "wb" ))
    
    
    f = open(config_file, 'w')
    f.write(( 'All_Hash\t' + str(All_Hash) + '\n' ))
    f.write(( 'pcap_file\t' + os.path.relpath(pcap_file, os.getcwd()) + '\n' ))
    f.write(( 'number_of_servers\t' + str(len(all_pairs)) + '\n' ))
    f.close()
    
    print 'len(all_pairs):', len(all_pairs), '\n'
    

    f = open(comm_file, 'w')
    for i in range(len(queue)):
        q = queue[i]
        if All_Hash is True:
            to_write_req = str(i) + '\tc\t' + str(q[0]) + '\t' + str(q[1]) + '\t' + str(q[2]) + '\n'
            to_write_res = str(i) + '\ts\t' + str(table[q[0]]) + '\t' + str(table[q[0]]) + '\n'
            to_write = to_write_req + to_write_res
        else:
            to_write_req = str(i) + '\tc\t' + str(len(q[0])) + '\t' + str(q[1]) + '\t' + str(hash(q[0])) + '\n'
            res = table[ hash(q[0]) ].pop(0)
            if res is not None:
                to_write_res = str(i) + '\ts\t' + str( len(res) ) + '\t' + str(q[1]) + '\t'  + str(hash(res)) + '\n'
            else:
                to_write_res = str(i) + '\ts\t' + '0' + '\t' + str(q[1]) + '\t'  + str(res) + '\n'
            
            to_write = to_write_req + to_write_res
        f.write(to_write)
        f.write('\n')
    f.close()
    
if __name__=="__main__":
    main()