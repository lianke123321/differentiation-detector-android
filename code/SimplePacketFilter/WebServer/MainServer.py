#!/usr/bin/python
from twisted.scripts.test.test_tap2rpm import _queryRPMTags
import tornado.ioloop
import tornado.web
import ctypes
import logging
import socket
import tornado.netutil
import subprocess
from recaptcha.client import captcha
import urllib
import httplib
import sys
from tornado.escape import json_encode


# The python files to manage the meddle pages
import MeddleCommunicator
import UserConfigs
import ConfigHandler

# The variables and string constants
from StringConstants import *
from ConfigHandler import configParams
import GetGraphData

#import smtplib
# THE PROBLEM HERE IS THAT SOUNDER HAS AN OLDER VERSION OF DJANGO RUNNING 
try:
    from django.core.validators import email_re
except:
    from django.forms.fields import email_re

ERR_CONN=1
ERR_NOUSER=2
ERR_OTHER=3
ERR_FAILUPDATE = 4
ERR_CAPTCHA = 5
ERR_EMAIL = 6
ERR_INVALIDARGS = 7



class CommonHandler(tornado.web.RequestHandler):
    mainErr = None
    
    def getERRPage(self):
        page = TEMPLATE_PAGE_HEADER                        
        if self.mainErr == ERR_CONN:
            page += "Unable to connect to the Packet Filter Server"
        elif self.mainErr == ERR_NOUSER:
            page += "This mobile device is currently not connected to Meddle. Please connect to Meddle to configure your settings"
        elif self.mainErr == ERR_FAILUPDATE:
            page += "Error updating the configuration at the Meddle Server. Please try again."
        elif self.mainErr == ERR_CAPTCHA:
            page += "Oops! We encountered a captcha error! Please try again."
        elif self.mainErr == ERR_EMAIL:
            page += "We encountered an error while validating your email! Please try again."
        elif self.mainErr == ERR_INVALIDARGS:
            page += "We encountered an error while validating the arguments."
        else:
            page += "Internal error on webserver. Please try again later."
        page += TEMPLATE_PAGE_FOOTER
        page = page.replace(SERVER_HOST_FILLER, configParams.getParam(MCFG_WEBSRV_HOST))
        page = page.replace(SERVER_PORT_FILLER, configParams.getParam(MCFG_WEBSRV_PORT))
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
        global configParams
        remoteIP = self.request.remote_ip
        if remoteIP.find(configParams.getParam(MCFG_TUN_IPPREFIX)) == -1:
            self.mainErr = ERR_NOUSER
            return None
        try:
            return self.__getIPInfo(remoteIP)
        except (socket.error, IOError), msg:
            self.mainErr = ERR_OTHER
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
        command = configParams.getParam(MCFG_MSG_SIGPATH) + " -c " + configParams.getConfigPath() + " -u " + str(ipInfo.userID)
        logging.warning("Sending the command " +str(command))
        process = subprocess.Popen(command, shell=True, stdout=subprocess.PIPE)        
        process.wait()
        logging.warning("The command returned with value"+str(process.returncode))
        if process.returncode == 0:
            return True
        self.mainErr = ERR_FAILUPDATE
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
            self.mainErr = ERR_NOUSER
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
            self.write(self.getERRPage())
        return

class ViewGraphHandler(CommonHandler):
    def __get(self):
        #ipInfo = self.getIpInfo()
        #if ipInfo is None:
        #    return self.getERRPage()
        # ipInfo.userID
        userID = 4
        queryType = self.get_argument('qt', True)
        logging.warning("Received a query of type"+str(queryType))
        if queryType == VIEWGRAPH_QT_RANGE:
            g = GetGraphData.GraphData(userID, 0, 0)
            retJson = g.getTimeRange()
            logging.warning(json_encode(retJson))
            self.set_header('Content-Type', 'application/json')
            self.write(json_encode(retJson))
            self.finish()            
            return
        if queryType == VIEWGRAPH_QT_GRAPH:
            minTs = self.get_argument('min', True)
            maxTs = self.get_argument('max', True)
            logging.warning("Requesing for range:" + str(minTs) + "to" + str(maxTs))
            g = GetGraphData.GraphData(userID, minTs, maxTs)
            retJson = g.getHttpFlowData()
            #logging.warning(retJson)
            #logging.warning(json_encode(retJson))
            self.set_header('Content-Type', 'application/json')
            self.write(json_encode(retJson))
            self.finish()
            return
        self.mainErr = ERR_INVALIDARGS
        logging.info("Error")
        self.write(self.getERRPage())
        return

    def get(self):
        try:
            self. __get()
        except (socket.error, IOError) , msg:
            logging.error("Error in POST message"+str(msg))
            self.write(self.getERRPage())

class DefaultHandler(CommonHandler):
    def get(self):
        global configParams
        try:
            self.render(str(configParams.getParam(MCFG_WEBPAGES_PATH))+"/index.html")
        except (socket.error, IOError), msg:
            self.write(self.getERRPage())
            
class SignUpHandler(CommonHandler):
    def __getThanksPage(self):
        global configParams
        #page = TEMPLATE_PAGE_HEADER
        #page += "<p>Thank you for your interest.</p>"
        #page += "<p><a href=\"http://"+configParams.getParam(MCFG_WEBSRV_HOST)+"/index.html\">Click here to return to home page</a></p> "
        #page += TEMPLATE_PAGE_FOOTER
        #page = page.replace(SERVER_HOST_FILLER, configParams.getParam(MCFG_WEBSRV_HOST))
        #page = page.replace(SERVER_PORT_FILLER, configParams.getParam(MCFG_WEBSRV_PORT))
        page = """<html><head><meta http-equiv="refresh" content="0; url= """+str(configParams.getParam(MCFG_IRB_URL))+"""">"""
        page += """</head><body> <p> Thank you for your interest.</p> If you are not taken to the form please click on this URL: """
        page += """<a href=\""""+str(configParams.getParam(MCFG_IRB_URL))+"""\">"""+str(configParams.getParam(MCFG_IRB_URL))+"""</a>"""
        page += """</body></html>"""
        return page
        
    def __verifyInput(self):
        global STR_CAPTCHA_PRIV_KEY
        
        recaptcha_challenge_field = self.get_argument('recaptcha_challenge_field', 'None')
        recaptcha_response_field = self.get_argument('recaptcha_response_field', 'None')
        logging.warning(str(recaptcha_challenge_field) + " " + str(recaptcha_response_field))
        response = captcha.submit(recaptcha_challenge_field, recaptcha_response_field, STR_CAPTCHA_PRIV_KEY, self.request.remote_ip)
        if response.is_valid is False:
            logging.warning("CAPTCHA Error")
            self.mainErr = ERR_CAPTCHA
            return False

        #logging.warning("Got a valid response")
        #emailAddress = self.get_argument('interestEmail', 'None')
        #if self.__validateEmail(emailAddress) is False:
        #    logging.warning("Error in entered email address:"+str(emailAddress));
        #    self.mainErr = ERR_EMAIL
        #    return False 
        return True
     
    def __validateEmail(self, emailAddr):
        return bool(email_re.match(emailAddr))
    
    def __serveNewInterest(self):
        global configParams
        emailAddress = self.get_argument('interestEmail', 'None')
        query = "INSERT INTO InterestedUsers VALUES (0, CURRENT_TIMESTAMP, '"+str(emailAddress)+"', 0 );"
        logging.warning(query);
        dbCon = tornado.database.Connection(host=configParams.getParam(MCFG_DB_HOST), 
                                            database=configParams.getParam(MCFG_DB_NAME),
                                            user=configParams.getParam(MCFG_DB_USER), 
                                            password=configParams.getParam(MCFG_DB_PASSWD))        
        results = dbCon.execute(query)
        dbCon.close()
        
        #emailMsg = TEMPLATE_INTEREST_EMAIL_BODY
        #emailMsg = emailMsg.replace(TEMPLATE_INTEREST_EMAIL_SUBMITTER, emailAddress)
        #smtp = smtplib.SMTP('localhost')
        #smtp.sendmail(TEMPLATE_INTEREST_EMAIL_SENDER, TEMPLATE_INTEREST_EMAIL_HANDLERS, emailMsg)
        return
        
    def __post(self):
        retVal = self.__verifyInput()
        if retVal == False:
            return self.getERRPage()
        #self.__serveNewInterest()
        return self.__getThanksPage()
    
    def post(self):
         try:
             logging.warning(self.request)
             ret = self.__post()
             self.write(ret)
         except:
             logging.error("Exception! Need to improve handling :)")
             self.write(self.getERRPage())
         return
             
                
#settings = {'debug': True, 
#            'static_path': os.path.join(STATICPATH)}


if __name__ == "__main__":
    if len(sys.argv) != 2:
        logging.error("python "+sys.argv[0] +" <configFileName>")
        sys.exit(-1)
    #endif     
    if False == configParams.readConfigs(sys.argv[1]):
        logging.error("Error while reading the config file")
        sys.exit(-1)
    reload(sys)
    sys.setdefaultencoding("utf-8")        
    handlers = [(r"/",DefaultHandler),
            (r""+str(PAGE_VIEWCONFIGS), ViewConfigsHandler),
            (r""+str(PAGE_VIEWGRAPH), ViewGraphHandler),
            (r"/dyn/signupCaptcha", SignUpHandler),
            (r"/(.+\..+)", tornado.web.StaticFileHandler, {'path': str(configParams.getParam(MCFG_WEBPAGES_PATH))})]
    settings = {}
    application = tornado.web.Application(handlers, **settings)
    application.listen(configParams.getParam(MCFG_WEBSRV_PORT))
    tornado.ioloop.IOLoop.instance().start()
