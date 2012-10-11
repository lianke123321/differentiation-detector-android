#include "MessageSender.h"
#include "MessageFrame.h"
#include "SimplePacketFilter.h"
#include "Logging.h"
#include <string.h>
#define UPCLIENT_CMD "up"
#define DOWNCLIENT_CMD "down"

bool checkArgs(const std::string &userName,const std::string &ipAddress, const std::string &cmdType)
{
	// Checking each of the arguments
	logInfo("Checking if the arguments : " << userName << " has length " << userName.length() <<
			 " which should be at most "<< USERNAMELEN_MAX <<
			 " and IP address " << ipAddress << " has length " << ipAddress.length() <<
			 " which must be at most " << INET_ADDRSTRLEN);
	if ((userName.length() > USERNAMELEN_MAX) || (ipAddress.length() > INET_ADDRSTRLEN)) {
		logError(" Length of user name " << userName.length() << " " << ( userName.length() > USERNAMELEN_MAX) <<
				 " and Length of user inet addr" << ipAddress.length() << " " << (ipAddress.length() > INET_ADDRSTRLEN));
		return false;
	}
	logInfo("Command is " << cmdType << " which must be either " << UPCLIENT_CMD << " " << DOWNCLIENT_CMD);
	if ((cmdType.compare(UPCLIENT_CMD) != 0) && (cmdType.compare(DOWNCLIENT_CMD) != 0)) {
		logError("Error in the command type " << (cmdType.compare(UPCLIENT_CMD)) << " " << (cmdType.compare(DOWNCLIENT_CMD)));
		return false;
	}
	return true;
}

bool sendCommand(const std::string &userName, const std::string &ipAddress, const std::string &cmdType)
{
	MessageSender cmdSender;
	msgTunnel_t cmdTunnel;
	bool ret;

	// Now send the commands
	logDebug("Checking if the socket " << cmdSender.sockFD << " can be used");
	if (cmdSender.sockFD < 0) {
		logError("Error opening socket to send command");
		return false;
	}

	logDebug("Creating the command " << cmdType << " for "<< ipAddress << " user:" << userName);
	memset(&cmdTunnel, 0, sizeof(msgTunnel_t));
	strncpy((char *)(cmdTunnel.ipAddress), (const char *)(ipAddress.c_str()), ipAddress.length());
	strncpy((char *)(cmdTunnel.userName), (const char *)(userName.c_str()), userName.length());
	cmdTunnel.userNameLen = userName.length();
	if(cmdType == UPCLIENT_CMD) {
		ret = cmdSender.sendCommand(MSG_CREATETUNNEL, cmdTunnel);
		logInfo("Sent Command "<<  MSG_CREATETUNNEL);
	} else if (cmdType == DOWNCLIENT_CMD) {
		ret = cmdSender.sendCommand(MSG_CLOSETUNNEL, cmdTunnel);
		logInfo("Sent Command "<<  MSG_CLOSETUNNEL);
	} else {
		logDebug("Unknown command");
		ret = false;
	}
	if (ret == false) {
		logError("Error sending the command "<< MSG_CREATETUNNEL);
	}
	return ret;
}

bool verifyCommand(const std::string &userName, const std::string &ipAddress, const std::string cmdType)
{
	MessageSender cmdSender;
	msgGetIPUserInfo_t cmdGetIP;
	msgRespIPUserInfo_t respIP;
	bool ret;
	uint32_t minlen = userName.length() < USERNAMELEN_MAX ? userName.length() : USERNAMELEN_MAX;
	// Now send the commands
	logDebug("Checking if the socket " << cmdSender.sockFD << " can be used");
	if (cmdSender.sockFD < 0) {
		logError("Error opening socket to send command");
		return false;
	}
	memset(&cmdGetIP, 0, sizeof(msgGetIPUserInfo_t));
	strncpy((char *)cmdGetIP.ipAddress, (const char *)(ipAddress.c_str()), ipAddress.length());
	logInfo("Verify the command " << cmdType << " for "<< ipAddress << " user:" << userName);
	ret = cmdSender.recvIPInfo(cmdGetIP, respIP);
	if (ret == false) {
		logError("Error in confirming the change in IP");
		return ret;
	}
	if(cmdType == UPCLIENT_CMD) {
		logInfo("The Name " << userName << " compare " << (userName.compare((const char *)(respIP.userName))));
		if (0 == userName.compare((const char *)(respIP.userName))) {
			logInfo("The names match; This implies that the User " << userName << " is bound to ip" << ipAddress);
			ret = true;
		} else {
			logError("The names match; This implies that the User " << userName << " is bound to ip" << ipAddress);
			ret = true;
		}
	} else if (cmdType == DOWNCLIENT_CMD) {
		if (respIP.userID == -1) {
			logInfo("Unable to find user; This implies that the User " << userName << " is now not bound to ip" << ipAddress);
			ret = true;
		}
		 else {
					logError("The names match; This implies that the User " << userName << " is bound to ip" << ipAddress);
					ret = true;
		}
	} else {
		logError("Unknown command");
		ret = false;
	}
	return ret;
}



int main(int argc, char *argv[])
{

	std::string userName, ipAddress, cmdType;
	bool ret;
	uint32_t cnt;

	// read the arguments <user-name> <ip-address> <up-client or down-client>
	if (argc != 4) {
		std::cout << argv[0] << " <userName> <ip-address> <up/down>" << std::endl;
		return -1;
	}
	userName = argv[1];
	ipAddress = argv[2];
	cmdType = argv[3];

	// TODO:: code to check the arguments
	if (false == checkArgs(userName, ipAddress, cmdType)) {
		logError("Error in the input arguments");
		return -1;
	}
	cnt = 0;
	while (cnt < 3) {
		ret = sendCommand(userName, ipAddress, cmdType);
		if (ret == true) {
			ret = verifyCommand(userName, ipAddress, cmdType);
			if (ret == true) {
				break;
			}
		}
		cnt = cnt + 1;
		logError("Retrying attempt" << cnt)
	}
	if (cnt < 3) {
		return 0;
	}
	return 1;
}
