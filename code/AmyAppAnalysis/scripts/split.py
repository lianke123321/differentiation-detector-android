
import  sys,  os

def splitFile(file):
 date = ''
 count = 0
 outputname = 'output/out' + str(count) + '.txt'
 #outfile = open(outputname, 'w')
 #outfile.write('Remember to clear out all files in this directory!')
 for line in open(file, 'r').readlines():
    l = line.strip().split('\t')
    if len(l) == 0:
        continue
    l = l[2].strip().split()
    if len(l) == 0:
        continue

    if date != l[0]:
        date = str(l[0])
        count = count + 1
        outputname = 'output/out' + date + '.txt'
        outfile = open(outputname, 'w')
    
    outfile.write(line)
    
            
def run():
   filename = sys.argv[1]
   splitFile(filename)


if __name__ == '__main__':
    run()
