'''
#######################################################################################################
#######################################################################################################

by: Arash Molavi Kakhki (arash@ccs.neu.edu)
    Northeastern University
    
Goal: This runs the tcp/udp_client script "rounds" times.
      Each round consists of a VPN and a NO VPN test

Inputs:
    Since this is calling tcp/udp_client.py, all the arguments necessary for those scripts should 
    be given to this one as well.

Usage:
    python vpn-no-vpn.py --script=[udp/tcp] --pcap_folder=../data/dropbox_d

#######################################################################################################
#######################################################################################################
'''

import sys, commands, time, subprocess, urllib2, threading
import tcp_client, udp_client, python_lib
from python_lib import Configs, PRINT_ACTION, tcpdump

def meddle_vpn(command):
    '''
    This function connects/disconnects the VPN
    
    NOTE: this is by nature platform dependent!
          current script is an AppleScript and for Max OS X
          Need scripts for Linux and maybe Windows (urgh!) too! should be straight forward
    '''
    if command in ['connect', 'disconnect']:
        print commands.getoutput('./meddle_vpn.sh ' + command)
    else:
        print 'command needs to be "connect" or "disconnect"'

def run_one(round, vpn=False, do_dumps=False):
    '''
    Runs the udp/tcp_client script once.
        - if vpn == True: use vpn, else do directly
        - if do_dumps == True, take a tcpdump of each replay
    '''
    if vpn:
        if do_dumps: dump = tcpdump(dump_name='vpn_'+str(round))
        meddle_vpn('connect')
    else:
        if do_dumps: dump = tcpdump(dump_name='novpn_'+str(round))
        meddle_vpn('disconnect')
    
    time.sleep(2)
    if do_dumps: dump.start(); time.sleep(2)

    if Configs().get('script').lower() == 'tcp': 
        tcp_client.run(sys.argv)
    elif Configs().get('script').lower() == 'udp':
        udp_client.run(sys.argv)
        
    while threading.activeCount() > 1:
        print 'Waiting for all threads to exit. (remaining threads: {})'.format((threading.activeCount()-1))
        time.sleep(2)
    
    if do_dumps: dump.stop(); time.sleep(2)

def main():
    '''Make sure the vpn is disconnected before starting'''
    meddle_vpn('disconnect')
    
    '''
    ######################################################################################
    Reading/setting configurations
    
    auto-server: This is to automated things more. If true, it sends a request to the machine
                 that hosting the server to run the server script (needs more work -- don't fully 
                 rely on it!)
    server-host: if auto-server is True, there will be a Tornado server running on the server
                 machine listening for server start up request. This is the ip address of the
                 Tornado server (basically the ip address of the replay server machine)
    server-port: the port number that Tornado server is running on
    rounds: number of rounds we want to run the test (each round is one VPN and one NO VPN run)
    instance: holds information about the instance the server is running on (see python_lib.py)
    ######################################################################################
    '''
    PRINT_ACTION('Creating configs', 0)
    configs = Configs()
    configs.set('auto-server', False)
    configs.set('server-host', 'ec2-54-204-220-73.compute-1.amazonaws.com')
    configs.set('server-port', 10001)
    configs.set('rounds', 1)
    configs.set('instance', 'achtung')
    configs.set('do_dumps', True)
    
    configs.read_args(sys.argv)
    
    configs.set('instance', python_lib.Instance(configs.get('instance')))
    configs.show_all()
    
    configs.check_for(['script', 'pcap_folder'])
    
    
#     if configs.get('auto-server'):
#         PRINT_ACTION('Sending request to the server', 0)
#         url = ('http://' + configs.get('server-host') + ':' + str(configs.get('server-port')) 
#             + '/re-run?pcap_folder=' + configs.get('pcap_folder'))
#         response = urllib2.urlopen(url).read()
#         print '\n', response
#         if 'Busy! Try later!' in response:
#             sys.exit(-1)
#         PRINT_ACTION('Giving server 10 seconds to get ready!', 0)
#         time.sleep(10)
    
    PRINT_ACTION('Firing off', 0)
    
    meddle_vpn('disconnect')
    
    for i in range(configs.get('rounds')):
        print '\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~'
        print 'DOING ROUND: {} -- VPN OFF'.format(i+1)
        print '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~'
        run_one(i, vpn=False, do_dumps=configs.get('do_dumps'))
        
        print '\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~'
        print 'DOING ROUND: {} -- VPN ON'.format(i+1)
        print '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~'
        run_one(i, vpn=True, do_dumps=configs.get('do_dumps'))
        print 'Done with round :{}\n'.format(i+1)
    
    meddle_vpn('disconnect')
    
if __name__=="__main__":
    main()