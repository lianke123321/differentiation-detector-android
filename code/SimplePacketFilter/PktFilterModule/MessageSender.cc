#include "MessageSender.h"
#include "MessageFrame.h"
#include "UserConfigs.h"
#include <string.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include "Logging.h"
#include <exception>
#include <boost/lexical_cast.hpp>

MessageSender::MessageSender()
{
	sockFD = -1;
}

bool MessageSender::connectToServer(std::string serverIP, std::string sockPort)
{
	uint16_t sockP = -1;
	if ((sockFD = socket(AF_INET, SOCK_STREAM, 0)) < 0) {
		sockFD = -1;
		logError("socket error");
		return false;
	}
	logDebug("Created the socket FD = " << sockFD);
	memset(&addr, 0, sizeof(addr));
	addr.sin_family = AF_INET;
	inet_pton(AF_INET, serverIP.c_str(), &(addr.sin_addr));
	try {
		sockP = boost::lexical_cast<uint16_t>(sockPort);
	} catch (...) {
		logError("Error in getting the socket port" << sockPort);
		sockFD = -1;
		return false;
	}
	addr.sin_port = htons(sockP); // TODO:: Modify this when reading from config file
	if (connect(sockFD, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
		logError("Connect error");
		sockFD = -1;
		return false;
	}
	logDebug("Successfully connected to socket");
	return true;
}

MessageSender::MessageSender(std::string serverIP, std::string sockPort)
{
	connectToServer(serverIP, sockPort);
}

MessageSender::~MessageSender()
{
	logDebug("Closing the socket FD " << sockFD);
	if (sockFD > 0) {
		close(sockFD);
		sockFD = -1;
	}
}

bool MessageSender::sendCommand(const uint32_t &cmd, const msgTunnel_t &cmdTunnel)
{
	MessageFrame cmdFrame = MessageFrame(cmd, cmdTunnel);
	uint32_t nwrite;

	if (NULL == cmdFrame.buffer || cmdFrame.frameLen < 0) {
		logError("Error creating Frame");
		return false;
	}
	logDebug("Created a Frame to send Command " << cmdFrame << " Now attempting a write");
	nwrite = write(sockFD, cmdFrame.buffer, cmdFrame.frameLen);
	if (nwrite != cmdFrame.frameLen || nwrite < 0) {
		logError("Error creating Frame");
		return false;
	}
	logDebug("Yippie sent the frame now returning" << cmdFrame);
	return true;
}

bool MessageSender::sendCommand(const msgLoadUserConfs_t &msgReadConfs, user_config_entry &entry)
{
	MessageFrame cmdFrame = MessageFrame(msgReadConfs);
	uint32_t nwrite, nread, offset;
	uint32_t reqRead = sizeof(msgHeader_t) + sizeof(msgRespUserConfs_t);
	uint8_t buffer [4096];

	if (NULL == cmdFrame.buffer || cmdFrame.frameLen < 0) {
		logError("Error creating Frame");
		return false;
	}
	logDebug("Created a Frame to send Command " << cmdFrame << " Now attempting a write");
	nwrite = write(sockFD, cmdFrame.buffer, cmdFrame.frameLen);
	if (nwrite != cmdFrame.frameLen || nwrite < 0) {
		logError("Error creating Frame");
		return false;
	}
	logDebug("Wrote the command, now waiting for the response");
	offset = 0;
	nread = 0;
	while (nread < reqRead) {
		int32_t tmpRead;
		tmpRead = read(sockFD, buffer+offset, reqRead - offset);
		if (tmpRead < 0) {
			logError("Error in the read");
			break;
		}
		nread = nread + tmpRead;
		offset = offset + tmpRead;
	}
	if (nread != reqRead) {
			// TODO:: do a while read
			logError("Error in receiving the response on user IP");
			return false;
	}
	MessageFrame respFrame = MessageFrame(buffer, nread);
	if( respFrame.cmdHeader->cmdType != MSG_RESPUSERCONFS) {
		logError("The response is not the UserConfs");
		return false;
	}
	memcpy((void *)&entry, (void *)&(respFrame.respUserConfs->entry), sizeof(user_config_entry));
	return true;
}

bool MessageSender::recvIPInfo(const msgGetIPUserInfo_t &getInfo, msgRespIPUserInfo_t &respIP)
{
	uint32_t nread, nwrite;
	uint8_t buffer [4096];
	uint32_t reqRead = sizeof(msgHeader_t) + sizeof(msgRespIPUserInfo_t);
	uint32_t offset=0;
	MessageFrame cmdFrame = MessageFrame(getInfo);

	memset(&respIP, 0, sizeof(respIP));
	if (NULL == cmdFrame.buffer || cmdFrame.frameLen < 0) {
		logError("Error creating Frame");
		return false;
	}

	logDebug("Created a Frame to send Command " << cmdFrame << " Now attempting a write");
	nwrite = write(sockFD, cmdFrame.buffer, cmdFrame.frameLen);
	if (nwrite != cmdFrame.frameLen || nwrite < 0) {
		logError("Error creating Frame");
		return false;
	}

	offset = 0;
	nread = 0;
	while (nread < reqRead) {
		int32_t tmpRead;
		tmpRead = read(sockFD, buffer+offset, reqRead - offset);
		if (tmpRead < 0) {
			logError("Error in the read operation");
			break;
		}
		nread = nread + tmpRead;
		offset = offset + tmpRead;
	}
	if (nread != reqRead) {
		// TODO:: do a while read
		logError("Error in receiving the response on user IP");
		return false;
	}
	MessageFrame respFrame = MessageFrame(buffer, nread);
	if( respFrame.cmdHeader->cmdType != MSG_RESPIPUSERINFO) {
		logError("The response is not the IP Info");
		return false;
	}
	memcpy((void *)&respIP, (void *)(respFrame.respIPUserInfo), sizeof(msgRespIPUserInfo_t));
	return true;
}
