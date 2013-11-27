'''
last_dump = ls -lrt | grep 'tcpdump' | tail -1 | awk '{ print $9}'
'''

import time, os, commands

pcap_folder = '/opt/meddle/pcap-data/'
date_folder = time.strftime('%Y-%b-%d', time.gmtime())
date_folder = '2013-Oct-15'
phone = 'iphone'
ssh_key = '~/.ssh/meddle'
username = 'ubuntu'
user = 'dave'
host = 'ec2-54-243-17-203.compute-1.amazonaws.com'


command = ('ssh -i ' + ssh_key + ' ' + username + '@' + host
          +' \"cd ' + pcap_folder + date_folder + '/' + user + phone
          +'; ls -lrt | tail -1\"')
file = (commands.getoutput(command)).split(" ")[-1]

print file

os.system('mkdir kir')

command = ('scp -i ' + ssh_key + ' ' + username + '@' + host + ':'
          + pcap_folder + date_folder + '/' + user + phone
          +'/' + file + ' ./kir/')

os.system(command)

#print command
