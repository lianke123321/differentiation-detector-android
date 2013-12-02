'''
last_dump = ls -lrt | grep 'tcpdump' | tail -1 | awk '{ print $9}'
'''

import time, os, commands, urllib2
from python_lib import Configs, PRINT_ACTION


#print command

def main():
    configs = Configs()
    configs.set('host', 'ec2-54-243-17-203.compute-1.amazonaws.com')
    configs.set('pcap_folder', '/opt/meddle/pcap-data/')
    configs.set('date_folder', time.strftime('%Y-%b-%d', time.gmtime()))
    configs.set('ssh_key', '~/.ssh/meddle')
    configs.set('username', 'ubuntu')
    
    configs.set('phone', 'iphone')
    configs.set('user', 'dave')

    configs.set('date_folder', '2013-Oct-15')
    
    command = ('ssh -i ' + configs.get('ssh_key') + ' ' + configs.get('username') + '@' + configs.get('host')
              +' \"cd ' + configs.get('pcap_folder') + configs.get('date_folder') + '/' + configs.get('user') + configs.get('phone')
              +'; ls -lrt | tail -1\"')
    file = (commands.getoutput(command)).split(" ")[-1]
        
    dir = file.partition('.')[0]
    os.mkdir(dir)    
    command = ('scp -i ' + configs.get('ssh_key') + ' ' + configs.get('username') + '@' + configs.get('host') + ':'
              + configs.get('pcap_folder') + configs.get('date_folder') + '/' + configs.get('user') + configs.get('phone')
              +'/' + file + ' ' + dir)
    os.system(command)
    
    client_ip = '1.2.3.4'
    os.system(('echo ' + client_ip + ' > ' + dir + '/client_ip.txt'))

if __name__=="__main__":
    main()
