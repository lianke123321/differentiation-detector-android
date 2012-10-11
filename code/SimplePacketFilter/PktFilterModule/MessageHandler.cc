#include "MessageHandler.h"
#include "Logging.h"
#include "UserConfigs.h"
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>
#include <string.h>
#include <arpa/inet.h>
#include "SimplePacketFilter.h"
#include <boost/thread/mutex.hpp>
#include <boost/thread/thread.hpp>

MessageHandler::MessageHandler()
{
	sockFD = 0;
}

MessageHandler::~MessageHandler()
{
	if (0 < sockFD) {
		close(sockFD);
	}
}

bool MessageHandler::setupMessageHandler(std::string socketPath)
{
	uint32_t len;

	logDebug("The socket path is of length " << socketPath.length() << " and the max length is " << sizeof(localAddr.sun_path));
	if (socketPath.length() > sizeof(localAddr.sun_path) - 1) {
		logError("The socket path " << socketPath.length() << " has a length larger than the maximum length " << sizeof(localAddr.sun_path));
		sockFD = -1;
		return false;
	}
	logDebug("Now connecting the socket");
	sockFD = socket(AF_UNIX, SOCK_STREAM, 0);
	if (0 > sockFD ) {
		logError("Error creating socket to read commands");
		sockFD = -1;
		return false;
	}
	memset(&localAddr, 0, sizeof(struct sockaddr_un));
	localAddr.sun_family = AF_UNIX;
	strncpy(localAddr.sun_path, socketPath.c_str(), sizeof(localAddr.sun_path)-1);
	unlink(localAddr.sun_path);
	len = strlen(localAddr.sun_path) + sizeof(localAddr.sun_family);
	if (bind(sockFD, (struct sockaddr *)&localAddr, len) == -1) {
		logError("Error in bind operation");
		close(sockFD);
		sockFD = -1;
		return false;
	}
	if (listen(sockFD, 5) == -1) {
		logError("Error listen");
		close(sockFD);
		sockFD = -1;
		return false;
	}
	logDebug("Successful in creating a socket at " << sockFD);
	return true;
}

MessageFrame* MessageHandler::recvCommand()
{
	uint32_t nRead, nwrite;
	memset(lastRead, 0, sizeof(lastRead));

	logDebug("Accepted a new connection: Reading for data on " << remoteFD);
	nRead = read(remoteFD, lastRead, sizeof(lastRead));
	logDebug("Read " << nRead << " bytes on socket" << remoteFD);
	if (nRead < 0) {
		logError("Error during the read operation");
		return cmd;
	}

	logDebug("Now parsing the received bytes");
	cmd = new MessageFrame(lastRead, nRead);
	if (cmd == NULL) {
		logError("Error creating the command");
		cmd = NULL;
		return cmd;
	}
	logDebug("Received the command " << cmd);
	return cmd;
}

bool MessageHandler::processTunnelCommand()
{
	// ignoring the name len for now
	std::string userName((char *)(cmd->cmdTunnel->userName));
	uint32_t userID;

	// TODO:: assuming IPv4 here and not performing any sanity checks
	in_addr_t ipAddress;

	if (inet_pton(AF_INET, (const char *)(cmd->cmdTunnel->ipAddress), (void *) &ipAddress) < 0) {
		logError("Error parsing the IP address");
		return false;
	}

	logInfo("Prev Table" << mainPktFilter.getIPMap());
	if (MSG_CREATETUNNEL == cmd->cmdHeader->cmdType) {
		if (false == mainPktFilter.associateUserToIp(userName, ipAddress)) {
			logError("Error adding the user" << cmd->cmdTunnel->userName);
			return false;
		}
	} else {
		if (false == mainPktFilter.disassociateIpFromUser(userName, ipAddress)) {
			logError("Error in removing the entry for ipAddress" << cmd->cmdTunnel->ipAddress << " for user "<< cmd->cmdTunnel->userName);
			return false;
		}
	}
	logInfo("New Table" << mainPktFilter.getIPMap());
	// TODO release the lock here
	return true;
}

bool MessageHandler::processReadAllConfs()
{
	return mainPktFilter.loadAllUserConfigs();
}

bool MessageHandler::respondGetUserIpInfo()
{
	in_addr_t ipAddress;
	uint32_t userID, nwrite;
	user_config_entry_t entry;
	msgRespIPUserInfo_t respIPUserInfo;
	MessageFrame *respFrame = NULL;

	if (inet_pton(AF_INET, (const char *)(cmd->cmdIPUserInfo->ipAddress), (void *) &ipAddress) < 0) {
		logError("Error parsing the IP address");
		return false;
	}
	if (false == mainPktFilter.getUserConfigs(ipAddress, userID, entry)) {
		logError("Error in getting the userConfigs for the IP" << cmd->cmdIPUserInfo->ipAddress);
		userID = -1;
		memset(&entry, 0, sizeof(entry));
	}

	memset(&respIPUserInfo, 0, sizeof(msgRespIPUserInfo_t));
	memcpy(respIPUserInfo.ipAddress, cmd->cmdIPUserInfo->ipAddress, sizeof(respIPUserInfo.ipAddress));
	respIPUserInfo.userID = userID;
	respIPUserInfo.userNameLen = strnlen((const char *)entry.userName, sizeof(respIPUserInfo.userName)-1);
	memcpy(respIPUserInfo.userName, entry.userName,  respIPUserInfo.userNameLen);

	logInfo("UserName "<<respIPUserInfo.userName << " User ID:" << respIPUserInfo.userID << " for IP "<< cmd->cmdIPUserInfo->ipAddress);
	respFrame = new MessageFrame(MSG_RESPIPUSERINFO, respIPUserInfo);
	if (NULL == respFrame) {
		logError("Error creating the response frame");
		return false;
	}
	logInfo("Created the Frame, now we are writing the response" << respFrame);
	nwrite = write(remoteFD, respFrame->buffer, respFrame->frameLen);
	if (nwrite != respFrame->frameLen) {
		logError("Incorrect bytes written in response to GetIPUserInfo");
		return false;
	}
	logDebug("Wrote the response"<< respFrame)
	delete respFrame;
	return true;
}

bool MessageHandler::processCommand()
{
	bool ret;
	if (NULL == cmd) {
		logError("NULL cmd passed");
		return false;
	}
	switch(cmd->cmdHeader->cmdType) {
	case MSG_CREATETUNNEL:
	case MSG_CLOSETUNNEL:
		logInfo("Processing the Tunnel command now");
		ret = processTunnelCommand();
		break;
	case MSG_READALLCONFS:
		logInfo("Processing the command to read configs");
		ret = processReadAllConfs();
		break;
	case MSG_GETIPUSERINFO:
		logInfo("Got the command to get the User details for a given ip");
		ret = respondGetUserIpInfo();
		break;
	default:
		break;
	}
	return ret;
}

bool MessageHandler::mainLoop()
{
	while(1) {
		this->cmd = NULL;
		// TODO:: Add pselect here with 100000 seconds and signal handler to ensure that thread receives signals quits
		logDebug("Waiting for a connection");
		if ((remoteFD = accept(sockFD, NULL, NULL)) < 0) {
			logError("Error during the accept operation");
			return cmd;
		}
		logInfo("Received a new connection request on " << remoteFD);
		this->cmd = recvCommand();
		// TODO:: Multiple threads to process these commands
		processCommand();
		logInfo("Served a command received on socket " << remoteFD);
		close(remoteFD);
		remoteFD = -1;
		delete this->cmd;
	}
	return true;
}



