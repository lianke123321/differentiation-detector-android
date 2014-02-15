'''
#######################################################################################################
#######################################################################################################

by: Arash Molavi Kakhki (arash@ccs.neu.edu)
    Northeastern University
    
Goal: this is a simple UDP server script for UDP testing

Usage:
    
ps aux | grep "python simple_udp_server.py" |  awk '{ print $2}' | xargs kill -9
#######################################################################################################
#######################################################################################################
'''
import sys, socket, threading

from python_lib import Configs, PRINT_ACTION, UDPset, ServerInstance

class Server(object):
    def __init__(self, instance):
        self.instance = instance
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.sock.bind((self.instance.ip, self.instance.port))
        print 'Created server at:', instance
    
    def listen(self):
        while True:
            data, address = self.sock.recvfrom(4096)
            print data, 'at', self.instance.port
            if data == 'CloseTheSocket':
                break
        self.close()
    #        inQ.append((data, instance.port))
    
    def close(self):
        self.sock.close()

class SideChannel(object):
    def __init__(self, instance):
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.sock.bind((instance.ip, instance.port))
        self.sock.listen(1)

    def wait_for_sync(self):
        connection, client_address = self.sock.accept()
        while True:
            data = connection.recv(4096)
            if data == 'Sync':
                connection.close()
                break
            
    def wait_for_termination(self, servers=[]):
        connection, client_address = self.sock.accept()
        while True:
            data = connection.recv(4096)
            if data == 'Terminate':
                print 'Got termination signal. Closing the socket.'
                connection.close()
                self.sock.close()
                break
    
def main():
    ip = '129.10.115.141'
    ports = [55055, 55056, 55057]
    sync_port = 55556
    
    side_channel = SideChannel(ServerInstance(ip, sync_port, 'SideChannel'))
    
    event   = threading.Event()
    inQ     = []
    threads = []
    servers = []
    
    for port in ports:
        servers.append(Server(ServerInstance(ip, port, str(port))))
        t = threading.Thread(target=servers[-1].listen)
        threads.append(t)
    
    PRINT_ACTION('Waiting for sync signal...', 0)
    side_channel.wait_for_sync()
    PRINT_ACTION('Got it!', 1)
    
    for t in threads:
        t.start()

    PRINT_ACTION('Waiting for termination signal...', 0)
    t = threading.Thread(target=side_channel.wait_for_termination, args=[servers])
    t.start()
    t.join()
    
#    while inQ:
#        print '\t', inQ[0][0], 'at', inQ[0][1]
#        inQ.pop(0)
#        print inQ.pop(0)
    
if __name__=="__main__":
    main()
    