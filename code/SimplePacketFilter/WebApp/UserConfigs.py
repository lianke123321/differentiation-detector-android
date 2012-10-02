import tornado.database
from StringConstants import *

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
        hstr = TEMPLATE_PAGE_HEADER+"""</head><body>"""
        return hstr
    
    def __footer(self):        
        fstr = TEMPLATE_PAGE_FOOTER
        return fstr
    
    def __htmlAds(self):
        adStr = "<ul><li>Filtering Ads and Analytics:"
        enabled = ""
        disabled = ""
        if self.filterAdsAnalytics == 1:
            enabled = "selected"            
        else:            
            disabled = "selected"
        adStr += """<select name="""+str(CFG_ADS_GRP)+""">"""      
        adStr += """ <option value = \""""+str(CFG_ADS_GRP_ENABLE_STR)+"""\""""+str(enabled)+"""> Enable</option>"""
        adStr += """ <option value = \""""+str(CFG_ADS_GRP_DISABLE_STR)+"""\""""+str(disabled)+"""> Disable</option>"""
        adStr += """</select></li><ul>"""
        #adStr += """ <li> <input type="radio" name="""+str(CFG_ADS_GRP)+""" value=\""""+str(CFG_ADS_GRP_ENABLE_STR)+"""\""""+str(enabled)+"""> Enable Ad Filtering</li>"""
        #adStr += """ <li> <input type="radio" name="""+str(CFG_ADS_GRP)+""" value=\""""+str(CFG_ADS_GRP_DISABLE_STR)+"""\""""+str(disabled)+"""> Disable Ad Filtering</li>"""
        #adStr += "</ul>"        
        return adStr
    
    def displayConfigs(self):
        page = ""
        page += self.__header()
        page += """<form name="input" action=\""""+str(PAGE_UPDATECONFIGS)+"""\" method="POST">"""
        page += "Configuration options:"
        page += self.__htmlAds()
        page += """<br/><input type="submit" value="Press to Submit and Update Settings"></form>"""
        page += self.__footer()
        return page
    
    def fetchConfigs(self, uid):
        query = "SELECT * FROM UserConfigs WHERE UserID = "+str(uid)+" ;"
        dbCon = tornado.database.Connection(host=DB_HOSTNAME, database=DB_DBNAME, user=DB_USER, password=DB_PASSWORD)
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
         query = "UPDATE UserConfigs SET filterAdsAnalytics="+str(self.filterAdsAnalytics)+" WHERE userID="+str(self.userID)+ " ;"         
         dbCon = tornado.database.Connection(host=DB_HOSTNAME, database=DB_DBNAME, user=DB_USER, password=DB_PASSWORD)
         results = dbCon.execute(query)
         dbCon.close()
         return 
          
if __name__ == "__main__":
    u = UserConfigs()
    u.fetchConfigs(1)
    print u.displayConfigs()
        
