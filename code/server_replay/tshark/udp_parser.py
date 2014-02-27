import sys
from scapy.all import *

def parse(pcap_file):
    a = rdpcap(pcap_file)
    udp_counter = 0
    for i in range(len(a)):
        p = a[i]
        try:
            udp = p['IP']['UDP']
            raw = p['Raw'].load
            udp_counter += 1
            print raw
        except:
            continue
    
    print udp_counter
    
def main():
    pcap = sys.argv[1]
    parse(pcap)

if __name__=="__main__":
    main()