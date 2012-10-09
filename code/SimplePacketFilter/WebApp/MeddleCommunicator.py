import socket
import sys
import struct

#TODO:: Add logging support

#define COMMAND_SOCKET_PATH "/data/.meddleCmdSocket"
COMMAND_SOCKET_PATH = "/data/.meddleCmdSocket"
#define CMD_ACK_POSITIVE 1
#define CMD_ACK_NEGATIVE 2
#define CMD_GETIPUSERINFO 6
#define CMD_RESPIPUSERINFO 7
#define USERNAMELEN_MAX 512
CMD_ACK_POSITIVE = 1
CMD_ACK_NEGATIVE = 2
CMD_READALLCONFS = 5
CMD_GETIPUSERINFO = 6
CMD_RESPIPUSERINFO = 7

INET_ADDRSTRLEN = 16
LEN_HDR = 8
LEN_USERNAME = 512
LEN_CMDACK = LEN_HDR # 4+4
LEN_RESPUSERINFO = LEN_HDR+INET_ADDRSTRLEN + 4 + 4 + LEN_USERNAME
#struct cmdHeader {
#    uint32_t cmdType;
#    uint32_t cmdLen; //placeholder ignored
#}__attribute__((packed));
#typedef struct cmdHeader cmdHeader_t;

#struct cmdIPUserInfo {
#    uint8_t ipAddress[INET_ADDRSTRLEN];
#}__attribute__((packed));
#
#typedef cmdIPUserInfo cmdIPUserInfo_t;

#struct respIPUserInfo {
#    uint8_t ipAddress[INET_ADDRSTRLEN];
#    uint32_t userID;
#    uint32_t userNameLen;
#    uint8_t userName[USERNAMELEN_MAX];
#}__attribute__((packed));

#typedef respIPUserInfo respIPUserInfo_t;

class IPUserInfo:
    ipAddress, userID, userName = None, None, None
    
    def __init__ (self, ipAdd, uid, uname):
        self.ipAddress = ipAdd
        self.userID = uid
        self.userName = uname

class MeddleCommunicator:
    sock = None
    sockPath = None 
        
    def __init__ (self):
        global COMMAND_SOCKET_PATH
        self.sock = -1;
        self.sockPath = COMMAND_SOCKET_PATH;
            
    def connectRemoteServer(self):        
        self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        try:
            self.sock.connect(self.sockPath)
        except socket.error, msg:
            return False            
        return True  
                       
    def __createHeader(self, cmdType, cmdLen):
        return struct.pack('@II', cmdType, cmdLen) # @ for native byte order 
    
    def __createIPUserRequestInfo(self, ipAddress):
        global CMD_GETIPUSERINFO, INET_ADDRSTRLEN       
        hdr = self.__createHeader(CMD_GETIPUSERINFO, INET_ADDRSTRLEN + 4 + 4);        
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
        global LEN_RESPUSERINFO, LEN_CMDACK, INET_ADDRSTRLEN
        frame = self.__createIPUserRequestInfo(ipAddress)
        try:
            self.sock.send(frame)
            #print "Sent Frame"         
            data = self.__getData(LEN_CMDACK + LEN_RESPUSERINFO)
            
            #print "Received an ACK/NACK"+str(len(data))+" "+str(LEN_CMDACK + LEN_RESPUSERINFO)        
            ackType, ackLen = struct.unpack('II',data[:LEN_CMDACK])
            if (ackType != CMD_ACK_POSITIVE):                
                return None
            data = data[LEN_CMDACK:];
            #print "Getting the response "+str(len(data))
            cmdType, cmdLen, ipAddress, userID, userNameLen, userName = struct.unpack('@II'+str(INET_ADDRSTRLEN)+'sII'+str(LEN_USERNAME)+'s',data)
            return IPUserInfo(ipAddress, userID, userName)            
            #print "IP " +str(ipAddress)+ " User ID"+str(userID)+"userNameLen:"+str(userNameLen)+"userName"+str(userName)             
        except socket.error, msg:
            #print msg            
            return None
        return None
    
    def commandReReadConfs(self):
        hdr = self.__createHeader(CMD_READALLCONFS, LEN_HDR)
        try:
            if self.connectRemoteServer() == False:
                return False
            self.sock.send(hdr)
            data = self.sock.recv(LEN_CMDACK);
            ackType, ackLen = struct.unpack('II',data[:LEN_CMDACK])
            if (ackType != CMD_ACK_POSITIVE):                
                return False            
        except socket.error, msg:
            return False
        return True
    
    def closeConnection():
        self.sock.close()

if __name__ == "__main__":
    m = MeddleCommunicator();
    ipAddress = "192.168.0.3"
    m.connectRemoteServer()
    m.requestUserInfo(ipAddress)
