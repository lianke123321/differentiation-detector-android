import tornado.database
from StringConstants import *
from ConfigHandler import configParams
import AuthTokenMap
import ConvisTemplate

class UserConfigs:
    userName = None
    userID = None
    filterAdsAnalytics = None    
        
    def __init__(self):
        self.__updateEntry(None)
    
    def __updateEntry(self, dbEntry):
        if dbEntry is not None:
            self.userName = dbEntry.userName
            self.userID = dbEntry.userID
            self.filterAdsAnalytics = dbEntry.filterAdsAnalytics
        else:
            self.userName, self.userID, self.filterAds = None, None, None
        return
    
    def __header(self):        
        hstr = TEMPLATE_PAGE_HEADER        
        return hstr
    
    def __footer(self):        
        fstr = TEMPLATE_PAGE_FOOTER
        return fstr
    
    def __htmlAds(self):
        # 	
        adStr = "<ul><li>When your phone contacts an ad server, Meddle should "
        enabled = ""
        disabled = ""
        if self.filterAdsAnalytics == 1:
            enabled = "selected"            
        else:            
            disabled = "selected"
        adStr += """<select name="""+str(CFG_ADS_GRP)+""" onChange="this.form.submit()">"""      
        adStr += """ <option value = \""""+str(CFG_ADS_GRP_ENABLE_STR)+"""\""""+str(enabled)+""">block ads</option>"""
        adStr += """ <option value = \""""+str(CFG_ADS_GRP_DISABLE_STR)+"""\""""+str(disabled)+""">allow ads</option>"""
        adStr += """</select>.</li><ul>"""
        return adStr

    def __linkGraph(self):
        authToken = AuthTokenMap.gAuthTokenMap.getAuthToken(str(self.userID))
        page = "<p><strong>Click the following URL to see which trackers are tracking your activities</strong><br/>"
        page = page + "<a href="+str(ConvisTemplate.CONVISURLTEMPLATE)+">"+str(ConvisTemplate.CONVISURLTEMPLATE)+"</a><br/>" 
        page = page + "<em>You can access the above URL from a desktop browser</em><br/>"       
        page = page + """<a href="mailto:yourmailaddress?subject=Meddle Tracker Graph&body="""
        page = page + str(ConvisTemplate.CONVISURLTEMPLATE)+"\">Click here to send this link by email</a></p>"
        page = page.replace(ConvisTemplate.authTokenPlaceholder, str(authToken))
        return str(page)
        
        
    def displayConfigs(self):
        page = ""
        page += self.__header()
        page += """<form name="input" action=\""""+str(PAGE_VIEWCONFIGS)+"""\" method="POST">"""
        page += "<strong>Meddle Policy</strong>"
        page += self.__htmlAds()
        page += """<br/></form>"""
        #page += """<br/><input type="submit" id=\""""+str(CFG_SUBMIT_ID)+"""\" value=\""""+str(CFG_SUBMIT_STR)+"""\"></form>"""
        page += self.__linkGraph()
        page += self.__footer()
        page = page.replace(SERVER_HOST_FILLER, configParams.getParam(MCFG_WEBSRV_HOST))
        page = page.replace(SERVER_PORT_FILLER, configParams.getParam(MCFG_WEBSRV_PORT))
        return page
    
    def fetchConfigs(self, uid):
        global configParams
        query = "SELECT * FROM UserConfigs WHERE UserID = "+str(uid)+" ;"
        dbCon = tornado.database.Connection(host=configParams.getParam(MCFG_DB_HOST), 
                                            database=configParams.getParam(MCFG_DB_NAME),
                                            user=configParams.getParam(MCFG_DB_USER), 
                                            password=configParams.getParam(MCFG_DB_PASSWD))
        results = dbCon.query(query)
        if results is not None and len(results) == 1:
             self.__updateEntry(results[0])
             return True
        dbCon.close()
        return False    
     
    def updateAdsConfig(self, ads_string):
         if ads_string == CFG_ADS_GRP_ENABLE_STR:
             self.filterAdsAnalytics = 1
         if ads_string == CFG_ADS_GRP_DISABLE_STR:
             self.filterAdsAnalytics = 0
         # If not one of the two then keep unchanged
         return
     
    def commitEntry(self):
         global configParams
         query = "UPDATE UserConfigs SET filterAdsAnalytics="+str(self.filterAdsAnalytics)+" WHERE userID="+str(self.userID)+ " ;"
         dbCon = tornado.database.Connection(host=configParams.getParam(MCFG_DB_HOST), 
                                            database=configParams.getParam(MCFG_DB_NAME),
                                            user=configParams.getParam(MCFG_DB_USER), 
                                            password=configParams.getParam(MCFG_DB_PASSWD))         
         results = dbCon.execute(query)
         query = "INSERT INTO UserConfigChange VALUES("+str(self.userID)+", CURRENT_TIMESTAMP, \"filterAdsAnalytics\", "+str(self.filterAdsAnalytics)+");"
         results = dbCon.execute(query)
         dbCon.close()
         return 
     
    def __str__(self):
         return " "+str(self.userName)+ " " +str(self.userID)+" "+str(self.filterAdsAnalytics)

if __name__ == "__main__":
    u = UserConfigs()
    u.fetchConfigs(1)
    print u.displayConfigs()        
