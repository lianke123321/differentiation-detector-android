import tornado.database
from ConfigHandler import configParams
import time
import sys
import logging
from StringConstants import *


# This object keeps the mapping between the user agent ID and the authToken
class AuthTokenMap:
    userAuthMap = None
    authUserMap = None    
    authCnt = None

    def __init__(self):
        self.userAuthMap = dict()
        self.authUserMap = dict()        
        self.authCnt = 0
        
    def populateMap(self):
        dbCon = tornado.database.Connection(host=configParams.getParam(MCFG_DB_HOST),
                                            database=configParams.getParam(MCFG_DB_NAME),
                                            user=configParams.getParam(MCFG_DB_USER),
                                            password=configParams.getParam(MCFG_DB_PASSWD))
        try:
            # Worst case we will see the same thing again and again is except is in the query.
            self.authCnt = 100
            query = "SELECT userID, authToken FROM UserAuthMap;"
            logging.warning(query)
            results = dbCon.query(query)
            tmpMap = dict()
            revMap = dict()
            for elem in results:
                tmpMap[str(elem.userID)] = str(elem.authToken)
                revMap[str(elem.authToken)] = str(elem.userID)
            self.userAuthMap = tmpMap
            self.authUserMap = revMap
            logging.warning(self.userAuthMap)
            logging.warning(self.authUserMap)
        finally:
            dbCon.close()
        return    

    def getUserID(self, authToken):
        self.authCnt = self.authCnt - 1
        if self.authCnt < 1:
            self.populateMap()                    
        userID = self.authUserMap.get(authToken, 0)
        return userID
        
    def getAuthToken(self, userID):
        self.authCnt = self.authCnt - 1        
        if self.authCnt < 1:
            self.populateMap()            
        authToken = self.userAuthMap.get(userID, 0)
        return authToken
        
gAuthTokenMap = AuthTokenMap()

if __name__ == "__main__":
    if len(sys.argv) != 2:
        logging.error("python "+sys.argv[0] +" <configFileName>")
        sys.exit(-1)
    #endif
    if False == configParams.readConfigs(sys.argv[1]):
        logging.error("Error while reading the config file")
        sys.exit(-1)
    for i in xrange (1,10):    
        print gAuthTokenMap.getAuthToken(1)
        print gAuthTokenMap.getUserID('abcdefghij123456')    
