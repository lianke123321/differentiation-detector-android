import tornado.database
from ConfigHandler import configParams
import time
import sys
import logging
from StringConstants import *

class UserActivityRange:
    userID = None
    minTs = None
    maxTs = None

    def __init__(self, uid):
        self.userID = uid;
        self.maxTs = time.time()
        self.minTs = 0;

    def setUserId(self, uid):
        self.userID = uid
        return True

    def __fetchEntry(self, dbEntry):
        if dbEntry is not None:
            self.minTs = dbEntry.minTs
            self.maxTs = dbEntry.maxTs
        else:
            self.minTs = 0
            self.maxTs = time.time()
        return True

    def fetchRange(self):
        global configParams
        #query = "SELECT min(timestamp) as minTs, max(timestamp) as maxTs FROM UserTunnelInfo WHERE userID = "+str(self.userID)+" ;"
        query = "SELECT min(ts) as minTs, max(ts) as maxTs FROM HttpFlowData WHERE userID = "+str(self.userID)+" ;"
        logging.info(query)
        dbCon = tornado.database.Connection(host=configParams.getParam(MCFG_DB_HOST),
                                            database=configParams.getParam(MCFG_DB_NAME),
                                            user=configParams.getParam(MCFG_DB_USER),
                                            password=configParams.getParam(MCFG_DB_PASSWD))
        results = dbCon.query(query)
        if results is not None and len(results) == 1:
             self.__fetchEntry(results[0])
        dbCon.close()
        return {'min':str(self.minTs), 'max':str(self.maxTs)}

class HttpFlowData:
    userID = None
    startTime = None
    stopTime = None
    httpData = None

    def __init__(self, uid, startT, stopT):
        self.userID = uid;
        self.startTime = startT
        self.stopTime = stopT
        self.httpData = dict()

    def __populateHttpData(self, results):
        logging.info(results)
        appMap = gAppData.getMap()
        agentMap = gAgentData.getMap()
        agentRevMap = gAgentData.getRevMap()
        for elem in results:            
#            logging.warning(elem)
            entryID = elem.appID
            entryName = appMap.get(elem.appID, None)
            if entryID == 0 or entryName is None:
                # Get the ID and name from the agent signature
                entryID = None
                entryName = agentMap.get(elem.agentID, None)
                if entryName is not None:
                    entryID = agentRevMap.get(entryName, None)
                    if entryID is not None:
                        entryID = entryID[0]
                        if entryName == "mozilla":
                            entryName = "default"
                        entryName = "*"+str(entryName)+"*"
                if entryID is None or entryName is None:
                    entryID = 0
                    entryName = "*-*"
            if entryName.find("/x") != -1:
                logging.warning(entryName)
                entryName = entryName.replace("/x","\\x")
                entryName = entryName.decode("string-escape")
                logging.warning(entryName)                
            entry = self.httpData.get(str(entryID), dict())                                
            entry['name'] = entryName
            entry['uses'] = int(entry.get('uses', 0)) + 1 #elem.numFlows
            entry['uses'] = str(entry['uses'])
            contacts = entry.get('contacts', {})
            contacts[str(elem.remoteHost)] = {'hits': str(elem.numFlows), 'tracker': str(elem.trackerFlag)}
            entry['contacts'] = contacts            
            entry['id'] = str(entryID)
            self.httpData[str(entryID)] = entry
        self.httpData = {"apps": self.httpData}
        return

    def fetchHttpData(self):
        global configParams
        #query = "SELECT min(timestamp) as minTs, max(timestamp) as maxTs FROM UserTunnelInfo WHERE userID = "+str(self.userID)+" ;"
        #query = " SELECT * FROM (SELECT COUNT(*) as numFlows, agentID, remoteHost, trackerFlag FROM HttpFlowData WHERE ts > "+str(self.startTime) + " AND ts < " + str(self.stopTime) + " GROUP BY agentID, remoteHost) a JOIN (SELECT agentID, agentSignature FROM UserAgentSignatures) b ON a.agentID = b.agentID;"
        query = "SELECT COUNT(*) as numFlows, appID, agentID, remoteHost, trackerFlag FROM HttpFlowData WHERE ts > "+str(self.startTime) + " AND ts < " + str(self.stopTime)+" AND userID = "+str(self.userID)+" GROUP by remoteHost" 
        logging.warning(query)
        dbCon = tornado.database.Connection(host=configParams.getParam(MCFG_DB_HOST),
                                            database=configParams.getParam(MCFG_DB_NAME),
                                            user=configParams.getParam(MCFG_DB_USER),
                                            password=configParams.getParam(MCFG_DB_PASSWD))
        results = dbCon.query(query)
        if results is not None and len(results) >= 1:
             self.__populateHttpData(results)
        dbCon.close()
        return self.httpData

class GraphData:
    userID = None
    startTime = None
    stopTime = None
    userData = None

    def __init__ (self, uid, startTime, stopTime):
        self.userID = uid;
        self.startTime = startTime
        self.stopTime = stopTime

    def getTimeRange(self):
        u = UserActivityRange(self.userID)
        return u.fetchRange()

    def getHttpFlowData(self):
        h = HttpFlowData(self.userID, self.startTime, self.stopTime)
        return h.fetchHttpData()

# This object keeps the mapping between the user agent ID and the agent signature
# The agent signature is used when the application ID is 0 -- We use a * notation after the signature to indicate a guess.
class AgentData:
    agentMap = None
    agentRevMap = None
    agentReqCnt = None

    def __init__(self):
        self.agentMap = dict()
        self.agentRevMap = dict()
        self.agentReqCnt = 0

    def populateMap(self):
        dbCon = tornado.database.Connection(host=configParams.getParam(MCFG_DB_HOST),
                                            database=configParams.getParam(MCFG_DB_NAME),
                                            user=configParams.getParam(MCFG_DB_USER),
                                            password=configParams.getParam(MCFG_DB_PASSWD))
        try:
            # Worst case we will see the same thing again and again is except is in the query.
            self.agentReqCnt = 1000            
            query = "SELECT agentID, agentSignature FROM UserAgentSignatures;"
            results = dbCon.query(query)
            tmpMap = dict()
            revMap = dict()
            for elem in results:
                tmpMap[elem.agentID] = elem.agentSignature
                tmpEntry = revMap.get(elem.agentSignature, [])
                tmpEntry.append(elem.agentID)
                revMap[elem.agentSignature] = tmpEntry                
            self.agentMap = tmpMap
            self.agentRevMap = revMap
        finally:
            dbCon.close()
        return    

    def getMap(self):
        if self.agentReqCnt < 1:
            self.populateMap()
        return self.agentMap

    def getRevMap(self):
        #rev map must be called after getMap for consistency
        return self.agentRevMap
        

# This object keeps the mapping between the appID and the application name        
class AppData:
    appMap = None
    appReqCnt = None

    def __init__(self):
        self.appMap = dict()
        self.appReqCnt = 0

    def populateMap(self):
        dbCon = tornado.database.Connection(host=configParams.getParam(MCFG_DB_HOST),
                                            database=configParams.getParam(MCFG_DB_NAME),
                                            user=configParams.getParam(MCFG_DB_USER),
                                            password=configParams.getParam(MCFG_DB_PASSWD))
        try:
            # Worst case we will see the same thing again and again is except is in the query.
            self.appReqCnt = 1000            
            query = "SELECT appID, appName FROM AppMetaData;"
            results = dbCon.query(query)
            tmpMap = dict()
            for elem in results:
                tmpMap[elem.appID] = elem.appName                
            self.appMap = tmpMap
        finally:
            dbCon.close()
        return    

    def getMap(self):
        if self.appReqCnt < 1:
            self.populateMap()
        return self.appMap


# GLOBAL VARIABLE THAT KEEPS THE APP and AGENT DATA IN MEMORY TO AVOID JOINS
gAppData = AppData()
gAgentData = AgentData()

if __name__ == "__main__":
    if len(sys.argv) != 3:
        logging.error("python "+sys.argv[0] +" <configFileName> <userID>")
        sys.exit(-1)
    #endif
    if False == configParams.readConfigs(sys.argv[1]):
        logging.error("Error while reading the config file")
        sys.exit(-1)
    g = GraphData(sys.argv[2], 0, 0)
    print g.getTimeRange()
    g = GraphData(sys.argv[2], 0, 1354635420)
    print g.getHttpFlowData()
