import sys
import os
import HTMLParser
import difflib
import urllib

SAFE_CHARS = '~()*!.\''

for filename in os.listdir(sys.argv[1]):
	print "File %s" % filename
	lastKey = None
	expected = None
	actual = None
	for line in open(sys.argv[1]+filename):
		if line.startswith("KEY:"):
			lastKey = line.split("KEY: ")[1].strip()
			continue
		elif line.startswith("VALUE: "):
			if lastKey is None: break
			if lastKey == "actualHTML":
				actual = line.split("VALUE: ")[1].strip()
			elif lastKey == "expectedHTML":
				expected = line.split("VALUE: ")[1].strip()
	
	if expected is None or actual is None: continue	
	#html_parser = HTMLParser.HTMLParser()
	#actual = html_parser.unescape(actual)
	#expected = html_parser.unescape(expected)
	actual = urllib.unquote(actual)
	expected = urllib.unquote(expected)
	with open('actual.txt', 'w+') as f:
		f.write(actual)
	with open('expected.txt', 'w+') as f:
		f.write(expected)

	print os.system("diff --suppress-common-lines -W 160  actual.txt expected.txt")

	print "HIT ENTER TO CONTINUE"
	sys.stdin.readline()	
