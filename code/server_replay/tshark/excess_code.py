def read_config_file(config_file):
    f = open(config_file, 'r')
    l = f.readline()
    while l:
        a = l.split()
        if a[0] == 'All_Hash':
            if a[1] == 'False':
                All_Hash = False
            elif a[1] == 'True':
                All_Hash = True
        if a[0] == 'pcap_file':
            pcap_file = a[1]
        if a[0] == 'number_of_servers':
            number_of_servers = int(a[1])
        l = f.readline()
    return All_Hash, pcap_file, number_of_servers


[q0, t0, c_s_pair] = stream_to_queue(follow_folder + '/follow-stream-0.txt', packet_dic)
[q1, t1, c_s_pair] = stream_to_queue(follow_folder + '/follow-stream-1.txt', packet_dic)
[q2, t2, c_s_pair] = stream_to_queue(follow_folder + '/follow-stream-2.txt', packet_dic)
[q3, t3, c_s_pair] = stream_to_queue(follow_folder + '/follow-stream-3.txt', packet_dic)
[q4, t4, c_s_pair] = stream_to_queue(follow_folder + '/follow-stream-4.txt', packet_dic)
[q5, t5, c_s_pair] = stream_to_queue(follow_folder + '/follow-stream-5.txt', packet_dic)
[q6, t6, c_s_pair] = stream_to_queue(follow_folder + '/follow-stream-6.txt', packet_dic)
stream_to_queue(follow_folder + '/follow-stream-3.txt', packet_dic)
stream_to_queue(follow_folder + '/follow-stream-4.txt', packet_dic)

queue = q0 + q1 + q2 + q3 + q4
queue = q6
table[c_s_pair] = t6

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

table = {'cs1': [
                     [len('c11'), hash('c11'), 's11'],
                     [len('c12'), hash('c12'), 's12'],
                     [len('c13'), hash('c13'), 's13'],
                     [len('c14'), hash('c14'), 's14'],
                     [len('c15'), hash('c15'), 's15'],
                     [len('c16'), hash('c16'),  None]
                     ],
             'cs2': [
                     [len('c21'), hash('c21'), 's21'],
                     [len('c22'), hash('c22'), 's22']
                     ]
             }
def stream_to_queue2(stream_file, packet_dic):
#    print 'Doing stream_to_queue:'
#    print '\t', stream_file
    client = convert_ip(((linecache.getline(stream_file, 5)).split()[2]).replace(':', '.'))
    server = convert_ip(((linecache.getline(stream_file, 6)).split()[2]).replace(':', '.'))
    c_s_pair = client + '-' + server

    f = open(stream_file, 'r')
    
    for i in range(6):
        f.readline()
    
    queue = []
    table = []
    res_array = []
    res = ''
    
    pl1 = (f.readline()).strip()
    pl1_hash = hash(pl1)
    
    if pl1[0] == '=':
        print 'Empty stream file!', stream_file 
        return queue, table, c_s_pair
    try:
        info1 = packet_dic[c_s_pair][pl1_hash].pop(0)
    except KeyError:
        print 'Broken stream file!', stream_file
        print '\tLook into it' 
        return queue, table, c_s_pair
    
    pl1_timestamp = info1[0]
    pl1_talking   = info1[1]
    
    assert(pl1_talking == 'c')
    
    pl2 = f.readline()
    while pl2 and pl2[0] != '=':
        pl2      = pl2.strip()
        pl2_hash = hash(pl2)
        try:
            info2 = packet_dic[c_s_pair][pl2_hash].pop(0)
        except KeyError:
            print 'Payload not in packet dic:'
            print pl2
            pl2 = f.readline()
            continue
        pl2_timestamp = info2[0]
        pl2_talking   = info2[1]
        if pl2_talking == 'c':
#            queue.append([pl1, c_s_pair, None, 0, pl1_timestamp])
            queue.append([pl1.decode("hex"), c_s_pair, None, 0, pl1_timestamp])
            assert(res_array == [])
            table.append([len(pl1.decode("hex")), hash(pl1.decode("hex")), []])
            
            pl1             = pl2
            pl1_hash        = pl2_hash
            pl1_timestamp = pl2_timestamp
            pl1_talking   = pl2_talking
            
            assert(res_array == [])
            pl2 = f.readline()
        
        elif pl2_talking == 's':
            res_array.append([pl2.decode("hex"), pl2_timestamp])
            res += pl2
            pl2  = f.readline()
            while pl2 and pl2[0] != '=':
                pl2      = pl2.strip()
                pl2_hash = hash(pl2)
#                print 'inner'
#                print pl2
#                print pl2_hash
                try:
                    info2           = packet_dic[c_s_pair][pl2_hash].pop(0)
                except KeyError:
                    print 'Payload not in packet dic:'
                    print pl2
                    pl2 = f.readline()
                    continue
                pl2_timestamp = info2[0]
                pl2_talking   = info2[1]
                
                if pl2_talking == 's':
                    res_array.append([pl2.decode("hex"), pl2_timestamp])
                    res += pl2
                    pl2 = f.readline()
                elif pl2_talking == 'c':
                    queue.append([pl1.decode("hex"), c_s_pair, hash(res.decode("hex")), len(res.decode("hex")), pl1_timestamp])
                    table.append([len(pl1.decode("hex")), hash(pl1.decode("hex")), res_array])
                    res_array = []
                    res       = ''
                    pl1             = pl2
                    pl1_hash        = pl2_hash
                    pl1_timestamp = pl2_timestamp
                    pl1_talking   = pl2_talking
                    pl2             = f.readline()
                    break
    
    if res_array == []:
        queue.append([pl1.decode("hex"), c_s_pair, None, 0, pl1_timestamp])
        assert(res_array == [])
        table.append([len(pl1.decode("hex")), hash(pl1.decode("hex")), []])
    else:
        queue.append([pl1.decode("hex"), c_s_pair, hash(res.decode("hex")), len(res.decode("hex")), pl1_timestamp])
        table.append([len(pl1.decode("hex")), hash(pl1.decode("hex")), res_array])
    
    return queue, table, c_s_pair