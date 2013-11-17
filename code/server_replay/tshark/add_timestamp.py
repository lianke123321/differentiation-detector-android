import os, sys

def main():    
    try:
        pcap_folder = sys.argv[1]
    except:
        print 'Usage: python scapy_parser.py [pcap_folder]'
        sys.exit(-1)

    pcap_file      = pcap_folder + '/' + os.path.basename(pcap_folder) + '.pcap'
    follow_folder  = pcap_folder + '/' + os.path.basename(pcap_folder) + '_follows'
    packets_file   = pcap_file + 'raw_packets.txt'
    
#    if not os.path.isfile(packets_file):
    print 'packets_file doesnt exist. Creating the packets_file...'
    command = ('tshark -r ' 
               + pcap_file 
               + ' -T fields -E separator=\';\' -e frame.time -e ip.src -e ip.dst -e tcp.port -e tcp.segment_data > ' 
               + packets_file)
    os.system(command)
    
    print ('tshark -r ' 
                   + pcap_file 
                   + ' -T fields -E separator=\';\' -e frame.time -e ip.src -e ip.dst -e tcp.port -e data > ' 
                   + packets_file)
    
    packets = {}
    pf = open(packets_file, 'r')
    l = pf.readline()
    while l:
        a = l.rpartition(';')
        info    = a[0]
        payload = a[2].strip()
        if payload == '':
            l = pf.readline()
            continue
#        print payload
#        if '47851' not in l:
#            print 'kir'
        
#        packets[hash(payload)] = info
        packets[payload] = info
        l = pf.readline()

    print len(packets)
#    sys.exit()
    for file in os.listdir(follow_folder):
        if 'follow-stream-' in file and 'TS' not in file:
            f  = open(os.path.join(follow_folder,file), 'r')
            of = open(os.path.join(follow_folder,file+'_TS.txt'), 'w')
            for i in range(6):
                of.write(f.readline())
            l = f.readline()
            while l:
                payload = l.strip()
                try:
#                    info = packets[hash(payload)]
                    info = packets[payload]
                    to_write = info + '\t' + payload + '\n'
                    of.write(to_write)
                except KeyError:
                    print 'kir'
                    print payload
                    sys.exit()
            f.close()
            of.close()
        
if __name__=="__main__":
    main()