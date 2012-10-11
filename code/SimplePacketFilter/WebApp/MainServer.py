#!/usr/bin/python
import tornado.ioloop
import tornado.web
import ctypes
import logging
import socket

import MeddleCommunicator
import UserConfigs

from StringConstants import *

ERR_CONN=1
ERR_NOUSER=2
ERR_OTHER=3

class CommonHandler(tornado.web.RequestHandler):
    mainErr = None
    
    def getERRPage(self):
        page = TEMPLATE_PAGE_HEADER + "</head><body>"                        
        if self.mainErr == ERR_CONN:
            page += "Unable to connect to the Packet Filter Server"
        elif self.mainErr == ERR_NOUSER:
            page += "This mobile device is currently not connected to Meddle. Please connect to Meddle to configure your settings"
        else:
            page += "Internal error on webserver. Please try again later."
        page += TEMPLATE_PAGE_FOOTER
        return page
     
    def __getIPInfo(self, remoteIP):
        m = MeddleCommunicator.MeddleCommunicator()
        if (False == m.connectRemoteServer()):
            self.mainErr = ERR_CONN;
            return None
        ipInfo = m.requestUserInfo(remoteIP)
        if None == ipInfo:
            self.mainErr = ERR_NOUSER
            logging.error("Unable to get the IP Info for ip"+str(remoteIP))
            m.closeConnection()
            return None
        if ipInfo.userID == ctypes.c_uint32(-1).value:
            self.mainErr = ERR_NOUSER
            logging.error("No User found for the given IP:"+str(remoteIP))
            m.closeConnection()
            return None
        m.closeConnection()
        return ipInfo
    
    def getIpInfo(self):
        remoteIP = self.request.remote_ip
        if remoteIP.find(PRIV_NETWORK) == -1:
            self.mainErr = ERR_NOUSER
            return None
        try:
            return self.__getIPInfo(remoteIP)
        except (socket.error, IOError), msg:
            self.mainErr == ERR_OTHER
            logging.error("Received exception"+str(msg))
        return None

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
        if self._finished is False: 
            self.write(page)
        return
    

class UpdateConfigsHandler(CommonHandler):
    
    def __post(self):
        logging.warning(self.request)
        retPage = ""
        cfg_ads = self.get_argument(CFG_ADS_GRP, 'None')
        if cfg_ads == 'None':
            return self.__getRedirectPage()            
        ipInfo = self.getIpInfo()
        if ipInfo is None:
            return self.getERRPage()
        uConfig = UserConfigs.UserConfigs()  
        if False == uConfig.fetchConfigs(ipInfo.userID):
            return __getNoUserPage()
        uConfig.updateAdsConfig(cfg_ads)
        uConfig.commitEntry()
        m = MeddleCommunicator.MeddleCommunicator()
        retPage = self.__getResponsePage()
        if m.commandReReadConfs() == False:
            retPage += "Failed"
        else:
            retPage += "Success"
        retPage += TEMPLATE_PAGE_FOOTER
        return retPage
        
    def post(self):
        try:
            retPage = self.__post()
            self.write(retPage)
        except (socket.error, IOError) , msg:
            logging.error("Error in POST message"+str(msg))
            self.write(self.getERRPage)
        return
    
    def __getResponsePage(self):
        return TEMPLATE_PAGE_HEADER + """<meta http-equiv="refresh" content="1;url=/"></head><body>Updating the Entry : """

    def __getRedirectPage(self):
        return TEMPLATE_PAGE_HEADER + """<meta http-equiv="refresh" content="1;url=/"><head><body>Redirecting to Home Page</body>"""
    
    def __getNoUserPage(self):
        return TEMPLATE_PAGE_HEADER + "Error getting the configurations for user at IP"+str(self.request.remote_ip) + TEMPLATE_PAGE_FOOTER
        
        
application = tornado.web.Application([
    (r"/", MainHandler),
    (r"/"+str(PAGE_UPDATECONFIGS), UpdateConfigsHandler)
])

if __name__ == "__main__":
    application.listen(80)
    tornado.ioloop.IOLoop.instance().start()
