import sys, os, math, commands, numpy

def do_one_file(filepath):
    outfile = (filepath.rpartition('/')[0]) + '/rtt_' + (filepath.rpartition('/')[2]).replace('stats.', '')
    parsed = {}
    f = open(filepath, 'r')
    try:
        for l in f:
            l = (l.strip()).partition(': ')
            parsed[l[0]] = math.ceil(float(l[2])*100)/100
#        print 'exp\t', 'ab_min\t', 'ab_max\t', 'ab_avg\t', 'ab_std\t', 'ba_min\t', 'ba_max\t', 'ba_avg\t', 'ba_std\t', 'loss'
#        print 'novpn\t', str(parsed['unencrypted_rtt_ab_min'])+'\t', str(parsed['unencrypted_rtt_ab_max'])+'\t', str(parsed['unencrypted_rtt_ab_avg'])+'\t', str(parsed['unencrypted_rtt_ab_stdev'])+'\t', str(parsed['unencrypted_rtt_ba_min'])+'\t', str(parsed['unencrypted_rtt_ba_max'])+'\t', str(parsed['unencrypted_rtt_ba_avg'])+'\t', str(parsed['unencrypted_rtt_ba_stdev'])+'\t', str(parsed['unencrypted_loss_rate'])
#        print 'novpn\t', str(parsed['encrypted_rtt_ab_min'])+'\t', str(parsed['encrypted_rtt_ab_max'])+'\t', str(parsed['encrypted_rtt_ab_avg'])+'\t', str(parsed['encrypted_rtt_ab_stdev'])+'\t', str(parsed['encrypted_rtt_ba_min'])+'\t', str(parsed['encrypted_rtt_ba_max'])+'\t', str(parsed['encrypted_rtt_ba_avg'])+'\t', str(parsed['encrypted_rtt_ba_stdev'])+'\t', str(parsed['encrypted_loss_rate'])
        f = open(outfile, 'w')
        f.write(('exp\t'+'ab_min\t'+'ab_max\t'+'ab_avg\t'+'ab_std\t'+'ba_min\t'+'ba_max\t'+'ba_avg\t'+'ba_std\t'+'loss' + '\n'))
        f.write(('novpn\t'+str(parsed['unencrypted_rtt_ab_min'])+'\t'+str(parsed['unencrypted_rtt_ab_max'])+'\t'+str(parsed['unencrypted_rtt_ab_avg'])+'\t'+str(parsed['unencrypted_rtt_ab_stdev'])+'\t'+str(parsed['unencrypted_rtt_ba_min'])+'\t'+str(parsed['unencrypted_rtt_ba_max'])+'\t'+str(parsed['unencrypted_rtt_ba_avg'])+'\t'+str(parsed['unencrypted_rtt_ba_stdev'])+'\t'+str(parsed['unencrypted_loss_rate']) + '\n'))
        f.write(('vpn\t'+str(parsed['encrypted_rtt_ab_min'])+'\t'+str(parsed['encrypted_rtt_ab_max'])+'\t'+str(parsed['encrypted_rtt_ab_avg'])+'\t'+str(parsed['encrypted_rtt_ab_stdev'])+'\t'+str(parsed['encrypted_rtt_ba_min'])+'\t'+str(parsed['encrypted_rtt_ba_max'])+'\t'+str(parsed['encrypted_rtt_ba_avg'])+'\t'+str(parsed['encrypted_rtt_ba_stdev'])+'\t'+str(parsed['encrypted_loss_rate']) + '\n'))
    except:
        print 'Broken:', filepath
def main():
#    do_one_file(sys.argv[1])
#    sys.exit()
    
    dir = os.path.abspath(sys.argv[1])
    results = dir + '/results/'
    
    for file in os.listdir(results):
        if file.endswith('.rtt.avg_stdev.novpn.txt'):
            break
    f = open(results+file, 'r')
    l = ((f.readline()).strip()).split()
    novpn_rtt_avg = l[1]
    novpn_rtt_std = l[3]
    f.close()
    
    for file in os.listdir(results):
        if file.endswith('.rtt.avg_stdev.vpn.txt'):
            break
    f = open(results+file, 'r')
    l = ((f.readline()).strip()).split()
    vpn_rtt_avg = l[1]
    vpn_rtt_std = l[3]
    f.close()
    
    out = commands.getoutput('ls -R ' + dir + ' | grep ".stats.txt"')
    
    novpn = []
    vpn   = []
    root = dir + '/generated_plots/'
    for l in out.splitlines():
        path = root + (l.partition('.stats.txt')[0]) + '/' + l
        if ('dump_vpn_' not in l) and ('dump_novpn_' not in l) and ('tcpdump-' not in l):
            continue
        f = open(path, 'r')
        for l in f:
            if 'loss_rate' in l:
                break
        if ('dump_novpn_' in path):
            novpn.append(float((l.strip()).split()[1]))
        elif ('tcpdump-' in path):
            vpn.append(float((l.strip()).split()[1]))    
    
    print ('novpn\t' + novpn_rtt_avg + '\t' + novpn_rtt_std + '\t' + str(numpy.average(novpn, axis=0)) + '\t' + str(numpy.std(novpn, axis=0)))
    print ('vpn\t' + vpn_rtt_avg + '\t' + vpn_rtt_std + '\t' + str(numpy.average(vpn, axis=0)) + '\t' + str(numpy.std(vpn, axis=0)))

if __name__=="__main__":
    main() 