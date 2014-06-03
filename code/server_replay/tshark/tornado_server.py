'''
 by:    Arash Molavi Kakhki
        arash@ccs.neu.edu
        Northeastern University
''' 

import tornado.ioloop
import tornado.web
import random
import datetime
import sys, time, commands
import subprocess, os
from python_lib import Configs, PRINT_ACTION
import python_lib

def print_req_details(req_handler):
    print 'Request details:'
    print '----------------'
    print '\tmethod:\t', req_handler.method
    print '\tfull_url:\t', req_handler.full_url()
    print '\turi:\t', req_handler.uri
    print '\thost:\t', req_handler.host
    print '\tpath:\t', req_handler.path
    print '\tremote_ip:\t', req_handler.remote_ip
    print '\tquery:\t', req_handler.query
    print '\targuments:\t', req_handler.arguments
    print '\tversion:\t', req_handler.version
    print '\tprotocol:\t', req_handler.protocol
    print '\tcookies:\t', req_handler.cookies
    
def print_req_headers(req_handler):
    print '\nRequest headers:'
    print '----------------'
    for k in sorted(req_handler.headers):
        print '\t', k, ': ', req_handler.headers[k]
class MainHandler(tornado.web.RequestHandler):
    def get(self):
        print '\n\n*******************Received GET!***********************'
class RecordReplay(tornado.web.RequestHandler):
    def get(self):
        try:
            user = self.request.arguments['user'][0]
        except KeyError:
            print 'Username not provided!'
            return
        print '\n\n*******************Received dump_ready notification!***********************'
        print time.strftime('%Y-%b-%d-%H-%M-%S', time.gmtime())
        print user

        self.write(("Hello " + user + ". I got your request.\n"))
        self.flush()
        self.write(("Your dump is being downloaded. Please wait...\n"))
        self.flush()

        p = subprocess.Popen(['python', 'wrapper_server.py', ('user='+user)], stdout=subprocess.PIPE)
        out, err = p.communicate()
        
        self.write(out)
        self.flush()
class ReRun(tornado.web.RequestHandler):
    def get(self):
        try:
            pcap_folder = self.request.arguments['pcap_folder'][0]
#            token       = self.request.arguments['token'][0]
        except KeyError:
            print 'pcap_folder not provided!'
            self.write('pcap_folder not provided!')
            return
        
        print '\n\n*******************Received ReRun request***********************'
        Configs().set('pcap_folder', pcap_folder)
        req_time = time.strftime('%Y-%b-%d-%H-%M-%S', time.gmtime())
        
        print req_time
        print Configs().get('pcap_folder')

        self.write(("Got your re-run request for: " + pcap_folder + "\n"))
        self.flush()
        self.write(("Setting up the servers. Please wait...\n"))
        self.flush()
        
        if pid_status(Configs().get('ReRun-pid')):
            print 'Busy! Try later!', Configs().get('ReRun-pid')
            self.write(('Busy! Try later! : ' + str(Configs().get('ReRun-pid')) + '\n'))
            return
        
        os.system("ps aux | grep \"python tcp_server.py\" |  awk '{ print $2}' | xargs kill -9")
        
        logfile = Configs().get('server-logs-folder') + req_time + '_log' + '.txt'
        errfile = Configs().get('server-logs-folder') + req_time + '_err' + '.txt'
        
        p = subprocess.Popen(['python', 'tcp_server.py'
                             , ('pcap_folder='+pcap_folder)
                             , ('host='+Configs().get('server-host'))]
                             , stdout=open(logfile, 'w')
                             , stderr=open(errfile, 'w'))
        print p.pid
        Configs().set('ReRun-pid', p.pid)
def pid_status(pid):
    if pid is None:
        return False
    try:
        os.kill(pid, 0)
        out = commands.getoutput('ps aux | grep ' + str(pid))
        if '<defunct>' in out:
            return False
        return True
    except OSError:
        return False
def main():
    configs = Configs()
    configs.set('server-host', 'ec2-54-204-220-73.compute-1.amazonaws.com')
    configs.set('port', 10001)
    configs.set('ReRun-pid', None)
    configs.set('server-logs-folder', 'server_logs/')
    python_lib.read_args(sys.argv, configs)

    print 'Server is running on port:', configs.get('port')
    
    if not os.path.exists(Configs().get('server-logs-folder')):
        os.makedirs(Configs().get('server-logs-folder'))
    
    application = tornado.web.Application([
        (r"/", MainHandler),
        (r"/re-run", ReRun),
        (r"/record-replay", RecordReplay)])
    
    application.settings = {"debug": True}
    application.listen(configs.get('port'))
    
    tornado.ioloop.IOLoop.instance().start()

if __name__ == "__main__":
    main()
