#include "CommandSender.h"
#include "CommandFrame.h"
#include "SimplePacketFilter.h"
#include "Logging.h"
#include <string.h>
#define UPCLIENT_CMD "up"
#define DOWNCLIENT_CMD "down"

bool checkArgs(std::string &userName, std::string &ipAddress, std::string &cmdType)
{
	// Checking each of the arguments
	if ((userName.length() > USERNAMELEN_MAX) || ipAddress.length() > INET_ADDRSTRLEN) {
		return false;
	}
	if (cmdType.compare(UPCLIENT_CMD) != 0 || cmdType.compare(DOWNCLIENT_CMD) != 0) {
		return false;
	}
	return true;
}


int main(int argc, char *argv[])
{
	CommandSender cmdSender;
	cmdTunnel_t cmdTunnel;
	std::string userName, ipAddress, cmdType;
	bool ret;

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

	// Now send the commands
	logDebug("Checking if the socket " << cmdSender.sockFD << " can be used");
	if (cmdSender.sockFD < 0) {
		logError("Error opening socket to send command");
		return -1;
	}

	logDebug("Creating the command " << cmdType << " for "<< ipAddress << " user:" << userName);
	memset(&cmdTunnel, 0, sizeof(cmdTunnel_t));
	strncpy((char *)(cmdTunnel.ipAddress), (const char *)(ipAddress.c_str()), ipAddress.length());
	strncpy((char *)(cmdTunnel.userName), (const char *)(userName.c_str()), userName.length());
	cmdTunnel.userNameLen = userName.length();
	if(cmdType == UPCLIENT_CMD) {
		ret = cmdSender.sendCommand(CMD_CREATETUNNEL, cmdTunnel);
		if (false == ret) {
			logError("Error sending the command "<< CMD_CREATETUNNEL);
		}
	} else if (cmdType == DOWNCLIENT_CMD) {
		ret = cmdSender.sendCommand(CMD_CLOSETUNNEL, cmdTunnel);
		if (false == ret) {
			logError("Error sending the command "<< CMD_CLOSETUNNEL)
		}
	} else {
		logDebug("Unknown command");
		ret = false;
	}

	if (false == ret) {
		logError("Error in sending command therefore returning -1");
		return -1;
	}
	logDebug("Its fine now I can quit");
	return 0;
}
