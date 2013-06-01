import sys 

fname = sys.argv[1]
#fname = "DaveDroidNoVPN.csv"
sampleInterval = 0.0002

f = open(fname, 'r')

total = 0
numSamples = 0
first = True
for line in f:
	if first:
		first = False
		continue
	parts = line.split(",")
	total += (float(parts[1]) * float(parts[2]))*sampleInterval
	numSamples +=1

print total
print total/numSamples
