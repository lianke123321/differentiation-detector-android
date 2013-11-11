import socket, sys, subprocess, commands, os

def socket_disconnect(sock):
    print 'Closing socket:', sock
    sock.shutdown(socket.SHUT_RDWR)
    sock.close()
    print 'Done'
def update_state(who, payload, state, snd_rcv):
    if who not in state:
        state[who] = {'sent' : None, 'rcvd' : None}
    state[who][snd_rcv] = hash(payload)
def check_events(event_list, state):
    if event_list is None:
        return True
    try:
        for e in event_list:
            if e is None:
                continue
            if (state[e[1]][e[2]] == e[0]) is False: 
                return False
        return True 
    except:
        return False
def get_all_tcp_servers(pcap_file, client_ip):
    ips = [client_ip]
    tcp_c = 0
    a = rdpcap(pcap_file)
    for i in range(len(a)):
        p = a[i]
        try:
            tcp = p['IP']['TCP']
            tcp_c += 1
            try:
                raw = p['Raw'].load
                if p['IP'].src not in ips:
                    ips.append(p['IP'].src)
                if p['IP'].dst not in ips:
                    ips.append(p['IP'].dst)
            except:
                pass
        except:
            pass
    print 'Number of packets:', len(a)
    print 'Number of TCP packets:', tcp_c
    for ip in ips:
        print ip
def append_to_file(line, filename):
    f = open(filename, 'a')
    f.write((line + '\n'))
    f.close()
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
def dir_list(dir_name, subdir, *args):
    '''
    Return a list of file names in directory 'dir_name'
    If 'subdir' is True, recursively access subdirectories under 'dir_name'.
    Additional arguments, if any, are file extensions to add to the list.
    Example usage: fileList = dir_list(r'H:\TEMP', False, 'txt', 'py', 'dat', 'log', 'jpg')
    '''
    fileList = []
    for file in os.listdir(dir_name):
        dirfile = os.path.join(dir_name, file)
        if os.path.isfile(dirfile):
            if len(args) == 0:
                fileList.append(dirfile)
            else:
                if os.path.splitext(dirfile)[1][1:] in args:
                    fileList.append(dirfile)
        # recursively access file names in subdirectories
        elif os.path.isdir(dirfile) and subdir:
            # print "Accessing directory:", dirfile
            fileList += dir_list(dirfile, subdir, *args)
    return fileList