#!/usr/bin/python
import tornado.ioloop
import tornado.web
import ctypes
import logging

import MeddleCommunicator
import UserConfigs

from StringConstants import *

ERR_CONN=1
ERR_NOUSER=2

class CommonHandler(tornado.web.RequestHandler):
    mainErr = None    
    
    def getERRPage(self):
        page = TEMPLATE_PAGE_HEADER + "</head><body>"        
        if self.mainErr == ERR_CONN:
            page += "Unable to connect to the Packet Filter Server"
        else:
            page += "This mobile device is currently not connected to Meddle. Please connect to Meddle to configure your settings"
        page += TEMPLATE_PAGE_FOOTER   
        return page
     
    def getIpInfo(self):
        remoteIP = self.request.remote_ip
        if remoteIP.find(PRIV_NETWORK) == -1:
            self.mainErr = ERR_NOUSER
            return None        
        m = MeddleCommunicator.MeddleCommunicator()
        if (False == m.connectRemoteServer()):
            self.mainErr = ERR_CONN;
            return None
        ipInfo = m.requestUserInfo(remoteIP)
        if None == ipInfo:
            self.mainErr = ERR_NOUSER
#            self.write("Unable to get user details for IP"+str(remoteIP))
            m.closeConnection()
            return None
        if ipInfo.userID == ctypes.c_uint32(-1).value:
            self.mainErr = ERR_NOUSER
#            self.write("Unable to get user details for IP"+str(remoteIP))
            m.closeConnection()
            return None
        m.closeConnection()
        return ipInfo
    
class MainHandler(CommonHandler):
    
    def get(self):
        logging.warning(self.request)
        self.mainErr = -1        
        self.dispPage(self.getIpInfo())
    
    def dispPage(self, ipInfo):
        if ipInfo is None:
            self.write(self.getERRPage())
            return
        uConfig = UserConfigs.UserConfigs()  
        if False == uConfig.fetchConfigs(ipInfo.userID):
            self.write("Error getting the configurations for user at IP"+str(self.request.remote_ip))
            return
        page = uConfig.displayConfigs()
        self.write(page)
        return            
    

class UpdateConfigsHandler(CommonHandler):
    
    def post(self):
        logging.warning(self.request)
        cfg_ads = self.get_argument(CFG_ADS_GRP, 'None')
        if cfg_ads == 'None':
            self.displayRedirect()
            return
        ipInfo = self.getIpInfo()
        if ipInfo is None:
            self.write(self.getERRPage())
            return
        uConfig = UserConfigs.UserConfigs()  
        if False == uConfig.fetchConfigs(ipInfo.userID):
            self.write("Error getting the configurations for user at IP"+str(self.request.remote_ip))
            return
        uConfig.updateAdsConfig(cfg_ads)
        uConfig.commitEntry()
        self.displayPage()
        m = MeddleCommunicator.MeddleCommunicator()
        if m.commandReReadConfs() == False:
            self.write("Failed")
        else:
            self.write("Success")
        self.write("</body>")            
        return
    
    def displayPage(self):
        page = TEMPLATE_PAGE_HEADER + """<meta http-equiv="refresh" content="2;url=/"></head><body>Updating the Entry : """
        self.write(page)

    def displayRedirect(self):
        page = TEMPLATE_PAGE_HEADER + """<meta http-equiv="refresh" content="1;url=/"><head><body>Redirecting to Home Page</body>"""
        self.write(page)       
        
        
application = tornado.web.Application([
    (r"/", MainHandler),
    (r"/"+str(PAGE_UPDATECONFIGS), UpdateConfigsHandler)
])

if __name__ == "__main__":
    application.listen(80)
    tornado.ioloop.IOLoop.instance().start()
