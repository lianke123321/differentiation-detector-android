'''
last_dump = ls -lrt | grep 'tcpdump' | tail -1 | awk '{ print $9}'
'''

import time, os, commands, urllib2, sys, subprocess
import python_lib
from python_lib import Configs, PRINT_ACTION


#print command

def do_all():
    os.system('rm /tmp/free_ports')
    
    PRINT_ACTION('Creating configs.', 1)
    configs = Configs()
    configs.set('meddle-host'       , 'ec2-54-243-17-203.compute-1.amazonaws.com')
    configs.set('meddle-username'   , 'ubuntu')
    configs.set('meddle-key'        , '~/.ssh/meddle')
    configs.set('meddle-pcap_folder', '/opt/meddle/pcap-data/')
    configs.set('meddle-date_folder', time.strftime('%Y-%b-%d', time.gmtime()))
#    configs.set('meddle-date_folder', '2013-Dec-02')
    
    configs.set('user' , 'arash')
    configs.set('phone', 'ios')
    
    python_lib.read_args(sys.argv, configs)
    
    
    PRINT_ACTION('Getting the dump name', 1)
    pcap_file = configs.get('meddle-pcap_folder') + configs.get('meddle-date_folder') + '/' + configs.get('user') + '-' + configs.get('phone')
    configs.set('pcap_file', pcap_file)
    command = ('ssh -i ' + configs.get('meddle-key') + ' ' + configs.get('meddle-username') + '@' + configs.get('meddle-host')
              +' \"cd ' + configs.get('pcap_file')
              +'; ls -lrt | tail -1\"')
    file = (commands.getoutput(command)).split(" ")[-1]
    dir  = './'+ file.rpartition('.')[0] + '/'
    
    configs.set('abs_file', os.path.abspath(dir) + '/' + file)
    configs.set('abs_dir', os.path.abspath(dir))
    PRINT_ACTION('file_abs_path: ' + configs.get('abs_file'), 2, False)

    PRINT_ACTION('Downloading the dump...', 1)    
    if not os.path.isdir(dir):
        os.mkdir(dir)
    command = ('scp -i ' + configs.get('meddle-key') + ' ' + configs.get('meddle-username') + '@' + configs.get('meddle-host') + ':'
              + configs.get('pcap_file')
              +'/' + file + ' ' + dir)
    os.system(command)
    
    PRINT_ACTION('Making client_ip file.', 1)
    try:
        configs.get('client_ip')
        os.system(('echo ' + configs.get('client_ip') + ' > ' + dir + '/client_ip.txt'))
    except KeyError:
        pass
    
    parse_trace = 'parse_trace.txt'
    PRINT_ACTION('Parsing the dump.', 1)
    PRINT_ACTION('Check "' + os.path.abspath(parse_trace) + '" for deatils.', 2, False)
    p1 = subprocess.Popen(['python', 'scapy_parser.py', dir]
                        , stdout=open((dir+'/'+parse_trace), 'w')
                        , stderr=open((dir+'/'+parse_trace+'_err.txt'), 'w'))
    p1.communicate()

    PRINT_ACTION('Running servers...', 1)
    p2 = subprocess.Popen(['python', 'tcp_server.py', ('pcap_folder='+dir)]
                         , stdout=open((dir+'/'+'kir.txt'), 'w')
                         , stderr=open((dir+'/'+'kir.txt'+'_err.txt'), 'w'))

    while not os.path.isfile('/tmp/free_ports'):
        PRINT_ACTION('Waiting for ports...', 2, False)
        time.sleep(5)
    PRINT_ACTION('You can now run your client side', 1)
    
def main():
    do_all()
    
if __name__=="__main__":
    main()
