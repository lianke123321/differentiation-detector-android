import sys, os, commands
import python_lib


def read_hex_part(file):
    f = open(file)
    f.readline()
    f.readline()
    f.readline()
    f.readline()
    f.readline()
    f.readline()
    
    hex_list = []
    l = f.readline()
    while l:
        if l[0] == '=':
            break
        hex_list.append( ((l.strip())[10:59]).replace(' ', '') )
        l = f.readline()
    return ''.join(hex_list) 
def main():
    try:
        file1 = sys.argv[1]
        dir1  = sys.argv[2]
        
        file2 = sys.argv[3]
        dir2  = sys.argv[4]
    except:
        'Give me two *pcap_communication" files to compare!!!'
        sys.exit(-1)

    print "\nComparing communication files..."
    map = {}
        
    f1 = open(file1, 'r')
    f2 = open(file2, 'r')
    
    a1 = f1.readline()
    b1 = f2.readline()
    
    while (a1 and b1):
        a2 = f1.readline()
        b2 = f2.readline()
        
        a3 = f1.readline()
        b3 = f2.readline()
        
        pair1 = a1.split()[3]
        pair2 = b1.split()[3]
        
        if pair1 not in map:
            map[pair1] = pair2
            
#            pair1_inv = pair1.split('-') 
#            pair1_inv.reverse()
#            pair2_inv = pair2.split('-') 
#            pair2_inv.reverse()
#            
#            map['-'.join(pair1_inv)] = '-'.join(pair2_inv) 
        else:
            if map[pair1] != pair2:
                print 'Mapping inconsistency:'
                print '\t', a1, '\t', a2, '\t', b1, '\t', b2
        
        if ((a1.split()[2] != b1.split()[2]) or 
            (a2.split()[2] != b2.split()[2]) or 
            (a1.split()[4] != b1.split()[4]) or 
            (a2.split()[4] != b2.split()[4])):
            print 'Payload inconsistency:'
            print '\t', a1, '\t', a2, '\t', b1, '\t', b2
        
        a1 = f1.readline()
        b1 = f2.readline()
    
    print '\tDone.'
    
    print '\nNow doing tshark check:'
    file_list1 = python_lib.dir_list(dir1, True)
    file_list2 = python_lib.dir_list(dir2, True)
    
    for f1 in file_list1:
        if ('.pcap' in f1) or ('.xml' in f1)  or ('follow-stream' in f1):
            continue
        name =  (f1.rpartition('/')[2]).rpartition('.')[0]
        suff =  (f1.rpartition('/')[2]).rpartition('.')[2]
        f2 = os.path.join(dir2, map[ name ]) + '.' + suff
#        f2 = os.path.join(dir2, map[ name ]) + '-'
#        print '\n'
#        print f1
#        print f2
        s1 = read_hex_part(f1)
        s2 = read_hex_part(f2)
        if s1 != s2:
            print '\nFlow inconsistency:'
            print f1
            print len(s1), hash(s1)
            print f2
            print len(s2), hash(s2)
    print '\tDone.\n'
        
if __name__=="__main__":
    main()