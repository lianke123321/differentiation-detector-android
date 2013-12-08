import sys, commands, time, subprocess, urllib2, threading
import tcp_client, python_lib
from python_lib import Configs, PRINT_ACTION

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
        print '\tDump stopped: {}'.format(self._interface, self._dump_name, self._p.pid)
        self._running = False
    def status(self):
        return self._running
def meddle_vpn(command):
    if command in ['connect', 'disconnect']:
        print commands.getoutput('./meddle_vpn.sh ' + command)
    else:
        print 'command needs to be "connect" or "disconnect"'
def run_one(rounds, vpn=False):
    print '\n~~~~~~~~~~~~~~ VPN = {} ~~~~~~~~~~~~~~~'.format(str(vpn))
    if vpn:
        dump = tcpdump(dump_name='vpn_'+str(rounds))
        meddle_vpn('connect')
    else:
        dump = tcpdump(dump_name='novpn_'+str(rounds))
        meddle_vpn('disconnect')
    time.sleep(2)
    dump.start()
    time.sleep(2)

    tcp_client.run(sys.argv)
    while threading.activeCount() > 1:
        print 'Waiting for all threads to exit. (remaining threads: {})'.format((threading.activeCount()-1))
        time.sleep(2)
    dump.stop()
    time.sleep(2)

def main():
    meddle_vpn('disconnect')
    
    PRINT_ACTION('Creating configs', 0)
    configs = Configs()
    configs.set('server-host', 'ec2-54-204-220-73.compute-1.amazonaws.com')
    configs.set('server-port', 10001)
    configs.set('auto-server', False)
    configs.set('rounds', 1)
    
    python_lib.read_args(sys.argv[1:], configs)
    
    configs.set('instance', python_lib.Instance(configs.get('instance')))
    configs.show_all()
    configs.get('instance').show()
    
    if configs.get('auto-server'):
        PRINT_ACTION('Sending request to the server', 0)
        url = ('http://' + configs.get('server-host') + ':' + str(configs.get('server-port')) 
            + '/re-run?pcap_folder=' + configs.get('pcap_folder'))
        response = urllib2.urlopen(url).read()
        print '\n', response
        if 'Busy! Try later!' in response:
            sys.exit(-1)
        PRINT_ACTION('Giving server 10 seconds to get ready!', 0)
        time.sleep(10)
    
    PRINT_ACTION('Firing off', 0)
    for i in range(configs.get('rounds')):
        print '\nDOING ROUND: {} -- VPN ON'.format(i+1)
        run_one(i, vpn=True)
        print '\nDOING ROUND: {} -- VPN OFF'.format(i+1)
        run_one(i, vpn=False)
        print 'Done with round :{}\n'.format(i+1)
    
if __name__=="__main__":
    main()