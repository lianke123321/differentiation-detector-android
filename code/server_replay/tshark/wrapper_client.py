import os, sys, socket, pickle, threading, time, ConfigParser, urllib2, subprocess
import python_lib 
from python_lib import Configs, PRINT_ACTION

def main():
    PRINT_ACTION('Creating configs', 0)
    configs = Configs()
    configs.set('server-host', 'ec2-72-44-56-209.compute-1.amazonaws.com')
    configs.set('server-host', 'achtung.ccs.neu.edu')
    configs.set('server-key', '~/.ssh/id_rsa')
    configs.set('server-port', 7600)
    configs.set('server-username', 'arash')
    configs.set('meddle-user', 'arash')
    
    python_lib.read_args(sys.argv, configs)

#    answer = 'n'    
#    while answer == 'n':
#        username = raw_input('What is your meddle username?\t').lower()
#        print 'Username is :', username
#        answer = raw_input('Is this correct? [Y/n]\t').lower()
#        while answer not in ['n', '']:
#            print 'Please answer with "y" or "n"'
#            answer = raw_input('Is this correct? [Y/n]\t').lower()
#    configs.set('user', username)
#    print '\nUsername set to:', username        
#    
#    print '\nPlease start the VPN on your phone and do your shit.'
#    print 'Once done with your shit, close the VPN connection and hit ENTER.'
#    raw_input('Waiting...\n\n')
#    answer = 'n'
#    while answer not in ['y', '']:
#        answer = raw_input('Are you done? [Y/n]\t').lower()
    
    PRINT_ACTION('Notifying the replay server', 0)
    url = ('http://' + configs.get('server-host') + ':' + str(configs.get('server-port')) 
        + '/dump_ready?user=' + configs.get('meddle-user'))
    
    response = urllib2.urlopen(url).read()
    print '\n', response
    
    PRINT_ACTION('Downloading files', 1)
    for l in response.splitlines():
        if 'file_abs_path:' in l:
            configs.set('remote_dir', (l.split()[1]).rpartition('/')[0])
            configs.set('local_dir', ((l.split()[1]).rpartition('/')[2]).rpartition('.')[0])
            break
    
    command = ('scp -r -i ' + configs.get('server-key') + ' ' + configs.get('server-username') + '@' + configs.get('server-host') + ':'
              + configs.get('remote_dir') + ' .')
    os.system(command)
    
    PRINT_ACTION('Running tcpdump!\n', 1)
    p = subprocess.Popen(['tcpdump', '-nn'
                         , '-w' , (configs.get('local_dir') + '/replay.pcap')])
    time.sleep(2)    
    
    PRINT_ACTION('Running client side!\n', 1)
    subprocess.call(['python', 'tcp_client.py', ('pcap_folder='+configs.get('local_dir'))])
    
    p.terminate()
    
if __name__=="__main__":
    main()