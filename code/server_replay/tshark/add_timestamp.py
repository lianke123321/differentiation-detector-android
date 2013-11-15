import os

def main():    
    try:
        pcap_folder = sys.argv[1]
    except:
        print 'Usage: python scapy_parser.py [pcap_folder]'
        sys.exit(-1)

    pcap_file      = pcap_folder + '/' + os.path.basename(pcap_folder) + '.pcap'
    follow_folder  = pcap_folder + '/' + os.path.basename(pcap_folder) + '_follows'
    packets_file   = pcap_file + 'packets_file.txt'
    
    command = 'tshark -r spotify.pcap -T fields -e frame.time -e data >' + packets_file
    os.system(command)
    
    
    
if __name__=="__main__":
    main()