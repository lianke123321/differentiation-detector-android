'''
#######################################################################################################
#######################################################################################################

by: Arash Molavi Kakhki (arash@ccs.neu.edu)
    Northeastern University
    
Goal: this is a simple UDP server-client script for UDP testing

Usage:
    

#######################################################################################################
#######################################################################################################
'''
import sys, socket
from python_lib import Configs, PRINT_ACTION

class Instance():
    def __init__(self, name, ip, port):
        self.name = name
        self.ip   = ip
        self.port = port
    def __str__(self):
        return '\tInstance: {} -- {}-{}'.format(self.name, self.ip, self.port)
    
def client(instance):
    MESSAGE = "Hello, World!"

    print "message:", MESSAGE
    
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.sendto(MESSAGE, (instance.ip, instance.port))

def server(instance):
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.bind((instance.ip, instance.port))
    
    while True:
        data, addr = sock.recvfrom(4096)
        print "received message:", data
        
def main():
    
    instance = Instance('auctung', '129.10.115.141', 55055)
    
    PRINT_ACTION('Reading/setting configs', 0)
    configs = Configs()
    configs.read_args(sys.argv)
    
    configs.check_for(['role'])
    
    if configs.is_given('ip'):
        setattr(instance, 'ip', configs.get('ip'))
    if configs.is_given('port'):
        setattr(instance, 'port', configs.get('port'))
        
    configs.show_all()
    print instance

    if configs.get('role') == 'server':
        server(instance)
    elif configs.get('role') == 'client':
        server(instance)
    
if __name__=="__main__":
    main()
    