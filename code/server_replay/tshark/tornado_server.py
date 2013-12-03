'''
 by:    Arash Molavi Kakhki
        arash@ccs.neu.edu
        Northeastern University
''' 

import tornado.ioloop
import tornado.web
import random
import datetime
import sys, time
import subprocess
from python_lib import Configs, PRINT_ACTION

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
class OtherHandler(tornado.web.RequestHandler):
    def get(self):
        try:
            user = self.request.arguments['user'][0]
        except KeyError:
            print 'Username not provided!'
            return
        print '\n\n*******************Received dump_ready notification!***********************'
        print datetime.datetime.now()
        print user

        self.write(("Hello " + user + ". I got your request.\n"))
        self.flush()
        self.write(("Your dump is being downloaded. Please wait...\n"))
        self.flush()

        p = subprocess.Popen(['python', 'wrapper_server.py', ('user='+user)], stdout=subprocess.PIPE)
        out, err = p.communicate()
        
        self.write(out)
        self.flush()

def main():
    try:
        port = int(sys.argv[1])
    except:
        port = 7600
        print 'Using the default port:', port
    
    print 'Server is running on port:', port
    
    application = tornado.web.Application([
        (r"/", MainHandler),
        (r"/dump_ready", OtherHandler)])
    
    application.settings = {"debug": True}
    application.listen(port)
    
    tornado.ioloop.IOLoop.instance().start()

if __name__ == "__main__":
    main()
