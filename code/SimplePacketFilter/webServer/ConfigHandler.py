#import ConfigVariables
import logging

class ConfigHandler:
    _path = None
    _fh = None
    _configDict = None

    def __init__ (self):
        self._path = None
        self._fh = None;        
        self._configDict = dict()
        
    def readConfigs(self, path):
        self._path = path
        try:
            self._fh = open(self._path,"r")
            self.__readConfigs()
        except:
            logging.error("Error reading the file"+self._path)
            pass
        return

    def __readConfigs(self):
        if self._fh is None:
            return
        for line in self._fh:
            confs = line.split('#')[0]
            confs = confs.strip()
            if len(confs) > 0:
                confLst = confs.split('=')
                if len(confLst) > 0 and len(confLst[0]) > 0:
                    #print confLst[0] + " " + confLst[1]                    
                    self._configDict[confLst[0]] = confLst[1]
                    #print confLst
                # end if
            #endif
        #endfor
        if self.validateRequiredKeys() is True:
            self.__expandShellVariables()
        return

    def __expandShellVariables(self):
        # A simple replace of the relative paths with the absolute paths!
        key = "webPagesStaticPath"
        shellVar = "MEDDLE_ROOT"
        value = self._configDict[key]
        value = value.replace("${"+shellVar+"}", self.getParam(shellVar))
        self._configDict[key] = value
        return
    
    def getParam(self, key):
        return self._configDict.get(key, None)

    def keysPresent(self, keyLst):
        for key in keyLst:
            if self._configDict.has_key(key) is False:
                logging.error("Error in finding the key"+str(key)+" in the config file"+str(self._path))
                return False
        return True

    def showAllConfs(self):
        retStr = ""
        if self._configDict is not None:
            for key, value in self._configDict.items():
                retStr = retStr + key + " " + value + "\n"
        return retStr
    
    def getConfigPath(self):
        return self._path
    # TODO:: Add to this list when you add a param that needs to be read from the config file
    def validateRequiredKeys(self):
        keyList = ["webServerPort", 
                   "webPagesStaticPath",
                   "msgSockPort",
                   "msgSockIpAddress",
                   "msgConfigChangePath",
                   "tunClientIpNetPrefix",
                   "dbServer",
                   "dbUserName",
                   "dbPassword",
                   "dbName"]
        if self.keysPresent(keyList) is False:
            logging.error("Error while reading the config file at "+str(self._path))            
            return False
        logging.critical("All keys in the list "+str(keyList)+ " are present in "+str(self._path))
        return True
    
    
# GLOBAL VARIABLE THAT KEEPS THE CONFIGURATION PARAMS
configParams = ConfigHandler()

if __name__ == "__main__":
    configParams.readConfigs("../PktFilterModule/meddle.config")
    configParams.validateRequiredKeys()
    print configParams.showAllConfs()
