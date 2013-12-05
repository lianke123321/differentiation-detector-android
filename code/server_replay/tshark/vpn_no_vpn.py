import sys, commands, time, subprocess
import tcp_client

class tcpdump(object):
    def __init__(self, dump_name=None, interface='en0'):
        self._p         = None
        self._interface = interface
        self._running   = False
        
        if dump_name is None:
            self._dump_name = 'dump_' + time.strftime('%Y-%b-%d-%H-%M-%S', time.gmtime()) + '.pcap'
        else:
            self._dump_name = 'dump_' + dump_name + '_' + time.strftime('%Y-%b-%d-%H-%M-%S', time.gmtime()) + '.pcap'
    def start(self):
        self._p = subprocess.Popen(['tcpdump', '-nn', '-i', self._interface, '-w', self._dump_name])
        print '\nStarted tcpdump on: {}'.format(self._interface, self._dump_name, self._p.pid)
        self._running = True
    def stop(self):
        print '\nStoping tcpdump on: {}'.format(self._interface, self._dump_name, self._p.pid)
        self._p.kill()
        self._running = False
    def status(self):
        return self._running
def meddle_vpn(command):
    if command in ['connect', 'disconnect']:
        print commands.getoutput('./meddle_vpn.sh ' + command)
    else:
        print 'command needs to be "connect" or "disconnect"'
    
def main():
    print 'With VPN',
    dump_vpn = tcpdump(dump_name='vpn')
    sys.stdout.flush()
    meddle_vpn('connect')
    dump_vpn.start()
    time.sleep(2)
    tcp_client.run(sys.argv)
    time.sleep(2)
    dump_vpn.stop()

    print 'Without VPN',
    dump_novpn = tcpdump(dump_name='novpn')
    sys.stdout.flush()
    meddle_vpn('disconnect')
    time.sleep(2)
    dump_novpn.start()
    tcp_client.run(sys.argv)
    time.sleep(2)
    dump_novpn.stop()
    
if __name__=="__main__":
    main()