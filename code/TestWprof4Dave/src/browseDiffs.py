import os
import subprocess

carrier = 'tmobile'
os_type = 'android'
base_dir = '/Users/choffnes/workspace/meddle/code/TestWprof4Dave/data/trip/'
for dirname, dirnames, filenames in os.walk(base_dir+carrier+'-'+os_type):
	for subdirname in dirnames:
        	subdir = os.path.join(dirname, subdirname)
		print subdir
		# do diff
		actual = os.path.join(subdir, 'actualHTML.txt')
		expected = os.path.join(subdir, 'expectedHTML.txt')
		diff_cmd = '/usr/bin/diff -b -B -d --side-by-side --suppress-common-lines -W 180 %s %s' % (actual, expected)
		print diff_cmd
		os.system(diff_cmd)
#		subprocess.check_output(diff_cmd,  stderr=subprocess.STDOUT)
		try:
			foo = input("Hit enter to continue")
		except SyntaxError:
			pass
