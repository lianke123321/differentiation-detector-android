import os, sys, socket, pickle, threading, time, ConfigParser, urllib2
import python_lib 
from python_lib import Configs, PRINT_ACTION

def main():
    PRINT_ACTION('Creating configs', 0)
    configs = Configs()
    configs.set('host', 'ec2-72-44-56-209.compute-1.amazonaws.com')
    configs.set('port', 7600)
    configs.set('username', 'ubuntu')
    configs.set('ssh_key', '~/.ssh/ancsaaa-keypair_ec2.pem')
    configs.set('user', 'arash')

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
    url = ('http://' + configs.get('host') + ':' + str(configs.get('port')) 
        + '/dump_ready?user=' + configs.get('user'))
    
    response = urllib2.urlopen(url).read()
    print '\n', response
    
if __name__=="__main__":
    main()


