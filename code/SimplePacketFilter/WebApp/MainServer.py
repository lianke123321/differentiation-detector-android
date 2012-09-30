import tornado.ioloop
import tornado.web
import ctypes

import MeddleCommunicator

class MainHandler(tornado.web.RequestHandler):
    
    def get(self):
        remoteIP = self.request.remote_ip
        m = MeddleCommunicator.MeddleCommunicator()
        if (False == m.connectRemoteServer()):
            self.write("Problem with connecting to Meddle")
            return
        ipInfo = m.requestUserInfo(remoteIP)
        if None == ipInfo:                         
            self.write("Unable to get user details for IP"+str(remoteIP))
            return
        if ipInfo.userID == ctypes.c_uint32(-1).value:
            self.write("Unable to get user details for IP"+str(remoteIP))
            return            
        self.write("IP address "+str(remoteIP) + " Hello, "+str(ipInfo.userName)+"; your User ID is " +str(ipInfo.userID))       
        self.write(self.request.remote_ip);
                

application = tornado.web.Application([
    (r"/", MainHandler),
])

if __name__ == "__main__":
    application.listen(8888)
    tornado.ioloop.IOLoop.instance().start()