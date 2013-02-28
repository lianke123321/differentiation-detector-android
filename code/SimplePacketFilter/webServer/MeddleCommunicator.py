import socket
import sys
import struct
import logging

from ConfigHandler import configParams

#TODO:: Add logging support

#define MSG_CREATETUNNEL 1
#define MSG_CLOSETUNNEL 2
#define MSG_LOADALLCONFS 3
#define MSG_GETIPUSERINFO 4
#define MSG_RESPIPUSERINFO 5
#define MSG_LOADUSERCONFS 6
#define MSG_RESPUSERCONFS 7
MSG_GETIPUSERINFO = 4
MSG_RESPIPUSERINFO = 5

INET_ADDRSTRLEN = 16
LEN_HDR = 8
LEN_USERNAME = 512
LEN_RESPUSERINFO = LEN_HDR+INET_ADDRSTRLEN + 4 + 4 + LEN_USERNAME

#struct msgIPUserInfo {
#    uint8_t ipAddress[INET_ADDRSTRLEN];
#}__attribute__((packed));
#typedef struct msgIPUserInfo msgGetIPUserInfo_t;
#struct respIPUserInfo {
#    uint8_t ipAddress[INET_ADDRSTRLEN];
#    uint32_t userID;
#    uint32_t userNameLen;
#    uint8_t userName[USERNAMELEN_MAX];
#}__attribute__((packed));
#typedef struct respIPUserInfo msgRespIPUserInfo_t;


class IPUserInfo:
    ipAddress, userID, userName = None, None, None
    
    def __init__ (self, ipAdd, uid, uname):
        self.ipAddress = ipAdd
        self.userID = uid
        self.userName = uname
    def __str__(self):
        return "IP:"+str(self.ipAddress)+":ID:"+str(self.userID)+":Name:"+str(self.userName)

class MeddleCommunicator:
    sock = None
    sockAddr = None 
        
    def __init__ (self):
        global configParams
        self.sock = -1;
        self.sockAddr = (configParams.getParam(MCFG_MSG_SRVIP), int(configParams.getParam(MCFG_MSG_SRVPORT)))
        logging.error("Connecting to "+str(self.sockAddr))
         
    def connectRemoteServer(self):
        self.sock = socket.socket()#socket.AF_INET, socket.SOCK_STREAM)
        try:
            logging.warning("Connecting to "+str(self.sockAddr))
            self.sock.connect(self.sockAddr)
            logging.warning("Connected to the Meddle server");
        except socket.error, msg:
            logging.error(msg)
            return False
        return True  
                       
    def __createHeader(self, cmdType, cmdLen):
        return struct.pack('@II', cmdType, cmdLen) # @ for native byte order 
    
    def __createIPUserRequestInfo(self, ipAddress):
        global MSG_GETIPUSERINFO, INET_ADDRSTRLEN
        hdr = self.__createHeader(MSG_GETIPUSERINFO, INET_ADDRSTRLEN + 4 + 4);
        payload = struct.pack('@'+str(INET_ADDRSTRLEN)+'s', ipAddress)
        return hdr+payload
        
    def __getData(self, length):
        data = ""
        while (len(data) < length):
            reqLen = length - len(data)  
            tmpData = self.sock.recv(reqLen) 
            data = data + tmpData
        return tmpData
 
    def requestUserInfo(self, ipAddress):
        global LEN_RESPUSERINFO, INET_ADDRSTRLEN
        frame = self.__createIPUserRequestInfo(ipAddress)
        try:
            self.sock.send(frame)
            #print "Sent Frame"         
            data = self.__getData(LEN_RESPUSERINFO)
            if data is None:
                logging.error("Error Getting the Info for user"+str(ipAddress))
                return None
            cmdType, cmdLen, ipAddress, userID, userNameLen, userName = struct.unpack('@II'+str(INET_ADDRSTRLEN)+'sII'+str(LEN_USERNAME)+'s',data)
            return IPUserInfo(ipAddress, userID, userName)
            #print "IP " +str(ipAddress)+ " User ID"+str(userID)+"userNameLen:"+str(userNameLen)+"userName"+str(userName)             
        except socket.error, msg:
            logging.error(msg)
            return None
        return None
    
    def closeConnection(self):
        try:
            self.sock.close()
        except socket.error, msg:
            logging.error(msg)

if __name__ == "__main__":
    #logging.Logger.setLevel(logging.DEBUG)
    m = MeddleCommunicator();
    m.connectRemoteServer()
    ipAddress = "10.11.3.3"
    print m.requestUserInfo(ipAddress)

