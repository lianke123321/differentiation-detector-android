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
    def __init__(self, ip, port):
        self.ip   = ip
        self.port = port
    def __str__(self):
        return '\tInstance: {}-{}'.format(self.ip, self.port)

def client(instance, message):
    print "Sending:", message
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.sendto(message, (instance.ip, instance.port))

def server(instance):
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.bind((instance.ip, instance.port))
    
    while True:
        data, addr = sock.recvfrom(4096)
        print "received message:", data
        if data == 'CloseTheSocket':
            sock.close()
            break

def main():
    ip = '129.10.115.141'
    ports = [55055, 55056, 55057]
    
    PRINT_ACTION('Reading/setting configs', 0)
    configs = Configs()
    configs.set('message', 'Hello world!')
    configs.read_args(sys.argv)
    
    configs.check_for(['role'])
    
    configs.show_all()
    print instance

    if configs.get('role') == 'server':
        for port in ports:
            instance = Instance(ip, port)
            server(instance)
            instances.append(instance)
    elif configs.get('role') == 'client':
        client(instances[0], '1')
        client(instances[0], '2')
        client(instances[1], '1')
        client(instances[0], '3')
        client(instances[2], '1')
        client(instances[1], '2')
        client(instances[2], '2')
        client(instances[0], '4')
        client(instances[1], '3')
        
        client(instances[0], 'CloseTheSocket')
        client(instances[1], 'CloseTheSocket')
        client(instances[2], 'CloseTheSocket')
    
if __name__=="__main__":
    main()
    