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
        print datetime.datetime.now()
        print_req_details(self.request)
        print_req_headers(self.request)
        self.set_cookie('my_cookie', 'my_cookie_value', domain=None, expires=None, path='/')
        self.set_header('Etag', 'my_Etag')
        self.add_header('my_header', 'my_header_here') 
        self.write(("I received your GET with following arguments: " + str(self.request.arguments)))
class OtherHandler(tornado.web.RequestHandler):
    def get(self):
        print '\n\n*******************Received dump_ready notification!***********************'
        print datetime.datetime.now()
        print_req_details(self.request)
        print_req_headers(self.request)
        try:
            user = self.request.arguments['user'][0]
            self.write(("Hello " + user + ". I got your request.\n"))
            self.write(("Your dump is being downloaded. Please wait...\n"))
            time.sleep(5)
            self.write(("Name of your dump is:"))
        except:
            print 'kir'


application = tornado.web.Application([
    (r"/", MainHandler),
    (r"/dump_ready", OtherHandler),
])

def main():
    try:
        port = int(sys.argv[1])
    except:
        port = 8888
        print 'Using the default port:', port
    
    print 'Server is running on port:', port
    application.settings = {"Debug": True}
    application.listen(port)
    tornado.ioloop.IOLoop.instance().start()

if __name__ == "__main__":
    main()
