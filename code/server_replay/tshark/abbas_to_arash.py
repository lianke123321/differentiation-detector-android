import sys, os, math

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
    
    dir = sys.argv[1]
    for file in os.listdir(os.path.abspath(dir)):
        if file.endswith("stats.txt"):
#            print file
            filepath = dir + '/' + file
            do_one_file(filepath)
#            print parsed['unencrypted_loss_rate'], '\t', parsed[''], '\t'

if __name__=="__main__":
    main() 