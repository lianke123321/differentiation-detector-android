'''
last_dump = ls -lrt | grep 'tcpdump' | tail -1 | awk '{ print $9}'
'''

import time, os, commands, urllib2



#print command

def main():
    configs = Configs()
    configs.set('pcap_folder', '/opt/meddle/pcap-data/')
    configs.set('date_folder', time.strftime('%Y-%b-%d', time.gmtime()))
    configs.set('phone', 'iphone')
    configs.set('ssh_key', '~/.ssh/meddle')
    configs.set('username', 'ubuntu')
    configs.set('user', 'dave')
    configs.set('host', 'ec2-54-243-17-203.compute-1.amazonaws.com')
    
    configs.set('date_folder', '2013-Oct-15')
    
    
    command = ('ssh -i ' + ssh_key + ' ' + username + '@' + host
              +' \"cd ' + pcap_folder + date_folder + '/' + user + phone
              +'; ls -lrt | tail -1\"')
    file = (commands.getoutput(command)).split(" ")[-1]
    
    print file
    print os.path.basename(file)
    os.path.basename(file)
    
#    response = urllib2.urlopen('http://achtung.ccs.neu.edu:8888/get_ip').read()
#    
#    
#    os.system('mkdir kir')
#    
#    command = ('scp -i ' + ssh_key + ' ' + username + '@' + host + ':'
#              + pcap_folder + date_folder + '/' + user + phone
#              +'/' + file + ' ./kir/')
#    
#    os.system(command)