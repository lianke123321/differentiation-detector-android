#include "MessageSender.h"
#include "MessageFrame.h"
#include "SimplePacketFilter.h"
#include "Logging.h"
#include <string.h>
#include "MeddleConfig.h"
#define UPCLIENT_CMD "up"
#define DOWNCLIENT_CMD "down"

typedef struct {
	std::string userName, tunnelIpAddress, cmdType, serverIpAddress, remoteIpAddress;
} sigArgs_t;

bool checkArgs(sigArgs_t &sigArgs)
{
	logInfo("Checking if the arguments : " << sigArgs.userName << " has length " << sigArgs.userName.length() <<
			" which should be at most "<< USERNAMELEN_MAX <<
			" and IP addresses " << sigArgs.tunnelIpAddress << "," << sigArgs.serverIpAddress << sigArgs.remoteIpAddress <<
			" have lengths " << sigArgs.serverIpAddress.length() << "," << sigArgs.serverIpAddress.length() << "," << sigArgs.remoteIpAddress.length() <<
			" which must be at most " << INET_ADDRSTRLEN);
	if ((sigArgs.userName.length() > USERNAMELEN_MAX) ||
			(sigArgs.tunnelIpAddress.length() > INET_ADDRSTRLEN) ||
			(sigArgs.remoteIpAddress.length() > INET_ADDRSTRLEN) ||
			(sigArgs.serverIpAddress.length() > INET_ADDRSTRLEN)) {
		logError(" Length of user name " << sigArgs.userName.length() << " " << (sigArgs.userName.length() > USERNAMELEN_MAX) <<
				" and Length of user inet addr" << sigArgs.tunnelIpAddress.length() << "," << sigArgs.serverIpAddress.length() <<  "," << sigArgs.remoteIpAddress.length() <<
				" > " << INET_ADDRSTRLEN);
		return false;
	}
	logInfo("Command is " << sigArgs.cmdType << " which must be either " << UPCLIENT_CMD << " " << DOWNCLIENT_CMD);
	if ((sigArgs.cmdType.compare(UPCLIENT_CMD) != 0) && (sigArgs.cmdType.compare(DOWNCLIENT_CMD) != 0)) {
		logError("Error in the command type " << (sigArgs.cmdType.compare(UPCLIENT_CMD)) << " " << (sigArgs.cmdType.compare(DOWNCLIENT_CMD)));
		return false;
	}
	return true;
}

bool sendCommand(MeddleConfig &meddleConfig, sigArgs_t &sigArgs)
{
	MessageSender cmdSender;
	msgTunnel_t cmdTunnel;
	bool ret;

	if (false == cmdSender.connectToServer(meddleConfig.msgSockIpAddress, meddleConfig.msgSockPort)) {
			logError("Error in connecting to server for sending the message");
			return false;
	}
	// Now send the commands -- this is redundant now!
	logDebug("Checking if the socket " << cmdSender.sockFD << " can be used");
	if (cmdSender.sockFD < 0) {
		logError("Error opening socket to send command");
		return false;
	}

	logDebug("Creating the command " << cmdType << " for "<< clientTunnelIpAddress << " user:" << userName);
	memset(&cmdTunnel, 0, sizeof(cmdTunnel));
	strncpy((char *)(cmdTunnel.clientTunnelIpAddress), (const char *)(sigArgs.tunnelIpAddress.c_str()), sigArgs.tunnelIpAddress.length());
	strncpy((char *)(cmdTunnel.clientRemoteIpAddress), (const char *)(sigArgs.remoteIpAddress.c_str()), sigArgs.remoteIpAddress.length());
	strncpy((char *)(cmdTunnel.meddleServerIpAddress), (const char *)(sigArgs.serverIpAddress.c_str()), sigArgs.serverIpAddress.length());

	strncpy((char *)(cmdTunnel.userName), (const char *)(sigArgs.userName.c_str()), sigArgs.userName.length());
	cmdTunnel.userNameLen = sigArgs.userName.length();
	if(sigArgs.cmdType == UPCLIENT_CMD) {
		ret = cmdSender.sendCommand(MSG_CREATETUNNEL, cmdTunnel);
		logInfo("Sent Command "<<  MSG_CREATETUNNEL);
	} else if (sigArgs.cmdType == DOWNCLIENT_CMD) {
		ret = cmdSender.sendCommand(MSG_CLOSETUNNEL, cmdTunnel);
		logInfo("Sent Command "<<  MSG_CLOSETUNNEL);
	} else {
		logError("Unknown command");
		ret = false;
	}
	if (ret == false) {
		logError("Error sending the command "<< MSG_CREATETUNNEL);
	}
	return ret;
}

bool verifyCommand(MeddleConfig &meddleConfig, sigArgs_t &sigArgs)
{
	MessageSender cmdSender;
	msgGetIPUserInfo_t cmdGetIP;
	msgRespIPUserInfo_t respIP;
	bool ret;

	if (false == cmdSender.connectToServer(meddleConfig.msgSockIpAddress, meddleConfig.msgSockPort)) {
		logError("Error in connecting to server for sending the message");
		return false;
	}

	// Now send the commands
	logDebug("Checking if the socket " << cmdSender.sockFD << " can be used");
	if (cmdSender.sockFD < 0) {
		logError("Error opening socket to send command");
		return false;
	}
	memset(&cmdGetIP, 0, sizeof(cmdGetIP));
	strncpy((char *)cmdGetIP.ipAddress, (const char *)(sigArgs.tunnelIpAddress.c_str()), sigArgs.tunnelIpAddress.length());
	logInfo("Verify the command " << sigArgs.cmdType << " for "<< sigArgs.tunnelIpAddress << " user:" << sigArgs.userName);
	ret = cmdSender.recvIPInfo(cmdGetIP, respIP);
	if (ret == false) {
		logError("Error in confirming the change in IP");
		return ret;
	}
	if(sigArgs.cmdType == UPCLIENT_CMD) {
		logInfo("The Name " << sigArgs.userName << " compare " << (sigArgs.userName.compare((const char *)(respIP.userName))));
		if (0 == sigArgs.userName.compare((const char *)(respIP.userName))) {
			logInfo("The names match; This implies that the User " << sigArgs.userName << " is bound to ip" << sigArgs.tunnelIpAddress);
			ret = true;
		} else {
			logError("The names do not match; This implies that the User " << sigArgs.userName << " is not bound to ip" << sigArgs.tunnelIpAddress);
			ret = false;
		}
	} else if (sigArgs.cmdType == DOWNCLIENT_CMD) {
		if (respIP.userID == 0) {
			logInfo("Unable to find user; This implies that the User " << sigArgs.userName << " is now not bound to ip" << sigArgs.tunnelIpAddress);
			ret = true;
		}
		 else {
			logError("User still exists. This implies that the User " << sigArgs.userName << " is not bound to ip" << sigArgs.tunnelIpAddress);
			ret = false;
		}
	} else {
		logError("Unknown command");
		ret = false;
	}
	return ret;
}

bool ParseCommandLine(std::string &configName, sigArgs_t &sigArgs, int argc, char *argv[])
{
	po::options_description desc("Allowed options");
	try {
		desc.add_options()
			("help,h", "produce help message")
			("configFile,f", po::value<std::string>(&configName)->required(), "the name of the config file")
			("userName,u", po::value<std::string>(&sigArgs.userName)->required(), "the name of the user who has gone up/down")
			("tunnelIpAddress,t", po::value<std::string>(&sigArgs.tunnelIpAddress)->required(), "the IP address of the client in the tunnel")
			("remoteIpAddress,r", po::value<std::string>(&sigArgs.remoteIpAddress)->required(), "the IP address assigned to the wireless interface at the client")
			("serverIp,s", po::value<std::string>(&sigArgs.serverIpAddress)->required(), "the IP address of the Meddle Server")
			("cmdType,c", po::value<std::string>(&sigArgs.cmdType)->required(), "the type of the command either 'up' or 'down'");
		po::variables_map vm;
		po::store(po::parse_command_line(argc, argv, desc), vm);
		if (vm.count("help")) {
			logError(desc);
			return false;
		}
		po::notify(vm);
	} catch(std::exception& e) {
		logError("Error: " << e.what());
		logError(desc);
		return false;
	} catch(...) {
		logError("Unknown error!");
		return false;
	}
	logInfo("You have provided '" << configName);
	return true;
}

int main(int argc, char *argv[])
{
	// std::string userName, tunnelIpAddress, cmdType, serverIP, remoteIpAddress;
	sigArgs_t sigArgs;
	MeddleConfig meddleConfig;
	std::string configName;
	bool ret;
	uint32_t cnt = 0;
	const uint32_t maxCnt = 5;

	// read the arguments <user-name> <ip-address> <up-client or down-client>
	if (false == ParseCommandLine(configName, sigArgs, argc, argv)) {
		logError("Error parsing command line arguments");
		return 1;
	}
	if (false == meddleConfig.ReadConfigFile(configName)) {
		logError("Error reading the configurations for meddle");
		return 1;
	}
	logInfo(meddleConfig);
	// TODO:: code to check the arguments
	if (false == checkArgs(sigArgs)) {
		logError("Error in the input arguments");
		return 1;
	}
	cnt = 0;
	while (cnt < maxCnt) {
		ret = sendCommand(meddleConfig, sigArgs);
		if (ret == true) {
			ret = verifyCommand(meddleConfig, sigArgs);
			if (ret == true) {
				break;
			}
		}
		cnt = cnt + 1;
		logError("Retrying attempt" << cnt);
	}
	if (cnt < maxCnt) {
		return 0;
	}
	return 1;
}
