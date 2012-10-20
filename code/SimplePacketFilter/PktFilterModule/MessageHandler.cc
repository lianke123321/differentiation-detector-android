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
	if (sockFD > 0) {
		close(sockFD);
	}
}

bool MessageHandler::setupMessageHandler(uint16_t sock_port)
{
	int32_t optVal = 1;
	uint32_t len;
	logDebug("Now connecting the socket" << sock_port);
	sockFD = socket(AF_INET, SOCK_STREAM, 0);
	if (sockFD < 0 ) {
		logError("Error creating socket to read commands");
		sockFD = -1;
		return false;
	}

	// Reuse the socket port -- required if the socket was not properly closed
	if (0 != setsockopt(sockFD, SOL_SOCKET, SO_REUSEADDR, &optVal, sizeof(optVal))) {
		logError("Error in setting the socket to reuse the address");
		sockFD = -1;
		return false;
	}

	memset(&localAddr, 0, sizeof(struct sockaddr_in));
	localAddr.sin_family = PF_INET;
	localAddr.sin_port = htons(sock_port);
	localAddr.sin_addr.s_addr = INADDR_ANY;
	len = sizeof(localAddr);
	if (bind(sockFD, (struct sockaddr *)&localAddr, len) < 0) {
		logError("Error in bind operation" << errno);
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

bool MessageHandler::processCloseTunnelCommand()
{
	// ignoring the name len for now
	std::string userName((char *)(cmd->cmdTunnel->userName));
	std::string clientTunnelIPStr((char *)cmd->cmdTunnel->clientTunnelIpAddress);
	std::string clientRemoteIPStr((char *)cmd->cmdTunnel->clientRemoteIpAddress);
	std::string serverIPStr((char *)cmd->cmdTunnel->meddleServerIpAddress);
	uint32_t userID;
	user_config_entry_t entry;
	// TODO:: assuming IPv4 here and not performing any sanity checks
	in_addr_t ipAddress;
	if (inet_pton(AF_INET, (const char *)(cmd->cmdTunnel->clientTunnelIpAddress), (void *) &ipAddress) < 0) {
		logError("Error parsing the IP address");
		return false;
	}
	// Get the user configs before disassoc
	memset(&entry, 0, sizeof(entry));
	if (false == mainPktFilter.getUserConfigs(ipAddress, userID, entry)) {
		logError("Error in getting the userConfigs for the IP" << cmd->cmdIPUserInfo->ipAddress << " Disassoc the User from IP");
		if (false == mainPktFilter.disassociateIpFromUser(userName, ipAddress)) {
			logError("Error dissociating the user");
		}
		logInfo("New Table after disasoc" << mainPktFilter.getIPMap());
		return false;
	}
	logInfo("Prev Table" << mainPktFilter.getIPMap());
	if (false == mainPktFilter.disassociateIpFromUser(userName, ipAddress)) {
		logError("Error adding the user" << cmd->cmdTunnel->userName);
		return false;
	}
	logInfo("New Table" << mainPktFilter.getIPMap());
	if (false == mainPktFilter.disassociateClientFromServerIp(userID, clientTunnelIPStr, clientRemoteIPStr, serverIPStr)) {
		logError("Error associating the client to the server IP" << clientTunnelIPStr << "<->" << serverIPStr);
		return false;
	}
	// TODO release the lock here
	return true;
}

bool MessageHandler::processCreateTunnelCommand()
{
	// ignoring the name len for now
	std::string userName((char *)(cmd->cmdTunnel->userName));
	std::string clientTunnelIPStr((char *)cmd->cmdTunnel->clientTunnelIpAddress); // Address in VPN Tunnel
	std::string clientRemoteIPStr((char *)cmd->cmdTunnel->clientRemoteIpAddress); // Global IP of the Client
	std::string serverIPStr((char *)cmd->cmdTunnel->meddleServerIpAddress); // Global IP of the server
	uint32_t userID;
	user_config_entry_t entry;
	// TODO:: assuming IPv4 here and not performing any sanity checks
	in_addr_t ipAddress;
	if (inet_pton(AF_INET, (const char *)(cmd->cmdTunnel->clientTunnelIpAddress), (void *) &ipAddress) < 0) {
		logError("Error parsing the IP address");
		return false;
	}
	if (false == mainPktFilter.loadUserConfigs(userName)) {
		logError("Error in reading the configs for the user " << userName);
		return false;
	}
	logInfo("Prev Table" << mainPktFilter.getIPMap());
	if (false == mainPktFilter.associateUserToIp(userName, ipAddress)) {
		logError("Error adding the user" << cmd->cmdTunnel->userName);
		return false;
	}
	// Read Configs here
	logInfo("New Table" << mainPktFilter.getIPMap());
	if (false == mainPktFilter.getUserConfigs(ipAddress, userID, entry)) {
		logError("Error in getting the userConfigs for the IP" << cmd->cmdIPUserInfo->ipAddress << " Disassoc the User from IP");
		if (false == mainPktFilter.disassociateIpFromUser(userName, ipAddress)) {
			logError("Error dissociating the user");
		}
		logInfo("New Table after diss" << mainPktFilter.getIPMap());
		return false;
	}
	if (false == mainPktFilter.associateClientToServerIp(userID, clientTunnelIPStr, clientRemoteIPStr, serverIPStr)) {
		logError("Error associating the client to the server IP" << clientTunnelIPStr << "<->" << serverIPStr);
		if (false == mainPktFilter.disassociateIpFromUser(userName, ipAddress)) {
			logError("Error dissociating the user");
		}
		return false;
	}

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
		logInfo("Processing the Tunnel command now");
		ret = processCreateTunnelCommand();
		break;
	case MSG_CLOSETUNNEL:
		logInfo("Processing the Tunnel command now");
		ret = processCloseTunnelCommand();
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
	// boo! i love ostriches who love these rets ;).
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



