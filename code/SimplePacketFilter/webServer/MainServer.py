#!/usr/bin/python
import tornado.ioloop
import tornado.web
import ctypes
import logging
import socket
import tornado.netutil
import subprocess

import MeddleCommunicator
import UserConfigs

from StringConstants import *

ERR_CONN=1
ERR_NOUSER=2
ERR_OTHER=3
ERR_FAILUPDATE = 4



class CommonHandler(tornado.web.RequestHandler):
    mainErr = None
    
    def getERRPage(self):
        page = TEMPLATE_PAGE_HEADER + "</head><body>"                        
        if self.mainErr == ERR_CONN:
            page += "Unable to connect to the Packet Filter Server"
        elif self.mainErr == ERR_NOUSER:
            page += "This mobile device is currently not connected to Meddle. Please connect to Meddle to configure your settings"
        elif self.mainErr == ERR_FAILUPDATE:
            page += "Error updating the configuration at the Meddle Server. Please try again."
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

class ViewConfigsHandler(CommonHandler):
    
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


    def __sendReloadMessage(self, ipInfo):
        # http://stackoverflow.com/questions/325463/launch-a-shell-command-with-in-a-python-script-wait-for-the-termination-and-ret
        command = SIGNAL_CONFIG_COMMAND_PATH + " " + str(ipInfo.userID)
        logging.warning("Sending the command " +str(command))
        process = subprocess.Popen(command, shell=True, stdout=subprocess.PIPE)        
        process.wait()
        logging.warning("The command returned with value"+str(process.returncode))
        if process.returncode == 0:
            return True
        self.mainErr == ERR_FAILUPDATE
        return False
    
    
    def __post(self):
        logging.warning(self.request)
        cfg_ads = self.get_argument(CFG_ADS_GRP, 'None')
        ipInfo = self.getIpInfo()
        logging.warning("IP info is "+str(ipInfo))
        if cfg_ads == 'None' or ipInfo is None:
            return self.dispPage(ipInfo)
        if ipInfo is None:
            return self.getERRPage()
        uConfig = UserConfigs.UserConfigs()
        logging.debug(uConfig)
        if False == uConfig.fetchConfigs(ipInfo.userID):
            self.mainErr == ERR_NOUSER
            return self.getERRPage()
        uConfig.updateAdsConfig(cfg_ads)
        uConfig.commitEntry()
        if self.__sendReloadMessage(ipInfo) is False:
            return self.getERRPage()
        return self.dispPage(ipInfo)
        
    def post(self):
        try:
            self.__post()
        except (socket.error, IOError) , msg:
            logging.error("Error in POST message"+str(msg))
            self.write(self.getERRPage)
        return
        
class DefaultHandler(CommonHandler):
    def get(self):
        try:
            self.render(STATICPATH+"/index.html")
        except (socket.error, IOError), msg:
            self.getERRPage()
            
            
handlers = [(r"/",DefaultHandler),
            (r""+str(PAGE_VIEWCONFIGS), ViewConfigsHandler),
            (r"/(.+\..+)", tornado.web.StaticFileHandler, {'path': str(STATICPATH)})]
settings = {}
#settings = {'debug': True, 
#            'static_path': os.path.join(STATICPATH)}

if __name__ == "__main__":
    application = tornado.web.Application(handlers, **settings)
    application.listen(80)
    tornado.ioloop.IOLoop.instance().start()
