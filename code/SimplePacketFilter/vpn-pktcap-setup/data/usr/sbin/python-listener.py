
import socket
import subprocess

def performFunction():
    subprocess.call(['/data/usr/sbin/decrypt-pcap.sh'])

soc = socket.socket(socket.AF_INET,socket.SOCK_STREAM)
soc.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1) 
# PORT IS AMY 1 13 25
soc.bind(('127.0.0.1',11325))
soc.listen(5)
while 1:
    print "Waiting"
    c1,a1 = soc.accept()
    print "Received"
    performFunction()
    c1.close()

       
